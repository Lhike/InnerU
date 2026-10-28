<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Marathon;
use App\Models\MarathonRegistration;
use App\Services\MarathonProgressService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\Response;

class MarathonController extends Controller
{
    public function __construct(private readonly MarathonProgressService $progress) {}

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $registrations = MarathonRegistration::query()
            ->where('user_id', $user->id)
            ->get()
            ->keyBy('marathon_id');

        $marathons = Marathon::query()
            ->where('is_published', true)
            ->orderBy('starts_at')
            ->get()
            // Open and upcoming races first, finished ones last.
            ->sortBy(fn (Marathon $m) => $m->phase() === 'ended' ? 1 : 0)
            ->values()
            ->map(fn (Marathon $m) => $this->payload($m, $registrations->get($m->id)));

        return response()->json(['marathons' => $marathons]);
    }

    public function show(Request $request, Marathon $marathon): JsonResponse
    {
        if (! $marathon->is_published) {
            return response()->json(['message' => 'Marathon not found.'], Response::HTTP_NOT_FOUND);
        }

        return response()->json([
            'marathon' => $this->payload($marathon, $this->registrationFor($request, $marathon)),
        ]);
    }

    public function register(Request $request, Marathon $marathon): JsonResponse
    {
        $window = $marathon->registrationStatus();
        if (! $marathon->is_published || $window === 'closed' || $marathon->phase() === 'ended') {
            return response()->json(['message' => 'Registration for this marathon is closed.'], Response::HTTP_UNPROCESSABLE_ENTITY);
        }
        if ($window === 'not_yet') {
            return response()->json([
                'message' => 'Registration opens on '.$marathon->registration_opens_at->format('M j, Y').'.',
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        $validated = $request->validate([
            'full_name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255'],
            'phone' => ['required', 'string', 'max:40'],
            'shirt_size' => ['required', Rule::in(MarathonRegistration::SHIRT_SIZES)],
            'shipping_address' => ['required', 'string', 'max:1000'],
        ]);

        $existing = $this->registrationFor($request, $marathon);
        if ($existing !== null && $existing->status !== 'rejected') {
            return response()->json(['message' => 'You already joined this marathon.'], Response::HTTP_CONFLICT);
        }

        $registration = DB::transaction(function () use ($request, $marathon, $validated, $existing): MarathonRegistration {
            $registration = $existing ?? new MarathonRegistration([
                'marathon_id' => $marathon->id,
                'user_id' => $request->user()->id,
            ]);
            $registration->fill($validated + [
                'status' => 'pending_payment',
                'rejection_reason' => null,
            ])->save();

            // Free marathons need no payment review.
            if ($marathon->price <= 0) {
                $this->confirm($registration, null);
            }

            return $registration->refresh();
        });

        return response()->json([
            'marathon' => $this->payload($marathon, $registration),
        ], Response::HTTP_CREATED);
    }

    public function submitPayment(Request $request, Marathon $marathon): JsonResponse
    {
        $registration = $this->registrationFor($request, $marathon);
        if ($registration === null || ! in_array($registration->status, ['pending_payment', 'rejected', 'payment_submitted'], true)) {
            return response()->json(['message' => 'There is no payment to submit for this marathon.'], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        $validated = $request->validate([
            'payment_reference' => ['required', 'string', 'max:120'],
            'payment_proof_url' => ['required', 'url', 'max:2048'],
        ]);

        $registration->fill($validated + [
            'status' => 'payment_submitted',
            'payment_submitted_at' => now(),
            'rejection_reason' => null,
        ])->save();

        return response()->json([
            'marathon' => $this->payload($marathon, $registration->refresh()),
        ]);
    }

    /** Everyone racing in [$marathon], for the race view in the leaderboard. */
    public function leaderboard(Request $request, Marathon $marathon): JsonResponse
    {
        if (! $marathon->is_published) {
            return response()->json(['message' => 'Marathon not found.'], Response::HTTP_NOT_FOUND);
        }

        $runners = $this->progress->standings($marathon)
            ->values()
            ->map(fn (array $row, int $index) => [
                'userId' => (string) $row['registration']->user_id,
                'name' => $row['registration']->user?->name ?? $row['registration']->full_name,
                'profilePic' => $row['registration']->user?->profile_pic,
                'walkerLook' => $row['registration']->user?->walker_look,
                'bibNumber' => $row['registration']->bib_number,
                'steps' => $row['steps'],
                'km' => $row['km'],
                'percent' => $row['percent'],
                'finished' => $row['finished'],
                'rank' => $index + 1,
            ]);

        return response()->json([
            'marathon' => $this->payload($marathon, $this->registrationFor($request, $marathon)),
            'runners' => $runners,
        ]);
    }

    public function certificate(Request $request, Marathon $marathon): JsonResponse
    {
        $registration = $this->registrationFor($request, $marathon);
        if ($registration !== null) {
            $this->progress->progress($registration);
            $registration->refresh();
        }

        if ($registration?->certificate_number === null) {
            return response()->json(['message' => 'Finish the marathon to get your certificate.'], Response::HTTP_NOT_FOUND);
        }

        return response()->json([
            'certificate' => [
                'number' => $registration->certificate_number,
                'runnerName' => $registration->full_name,
                'marathonTitle' => $marathon->title,
                'theme' => $marathon->theme,
                'themeData' => $marathon->theme_data,
                'distanceKm' => $marathon->distance_km,
                'bibNumber' => $registration->bib_number,
                'finishedAt' => $registration->finished_at?->toIso8601String(),
            ],
        ]);
    }

    /**
     * Confirms a registration and gives it the next bib number. Call inside
     * a transaction: locking the marathon row serialises approvals so two
     * runners never get the same bib. (PostgreSQL can't lock an aggregate
     * like MAX() directly.)
     */
    public static function confirm(MarathonRegistration $registration, ?int $reviewerId): void
    {
        Marathon::query()->whereKey($registration->marathon_id)->lockForUpdate()->first();

        $bib = $registration->bib_number ?? ((int) MarathonRegistration::query()
            ->where('marathon_id', $registration->marathon_id)
            ->max('bib_number')) + 1;

        $registration->forceFill([
            'status' => 'confirmed',
            'bib_number' => $bib,
            'reviewed_by' => $reviewerId,
            'reviewed_at' => now(),
            'rejection_reason' => null,
        ])->save();
    }

    private function registrationFor(Request $request, Marathon $marathon): ?MarathonRegistration
    {
        return MarathonRegistration::query()
            ->where('marathon_id', $marathon->id)
            ->where('user_id', $request->user()->id)
            ->first();
    }

    private function payload(Marathon $marathon, ?MarathonRegistration $registration): array
    {
        return [
            ...self::marathonPayload($marathon),
            'myRegistration' => $registration === null ? null : [
                'status' => $registration->status,
                'fullName' => $registration->full_name,
                'shirtSize' => $registration->shirt_size,
                'bibNumber' => $registration->bib_number,
                'rejectionReason' => $registration->rejection_reason,
                'paymentReference' => $registration->payment_reference,
                'finishedAt' => $registration->finished_at?->toIso8601String(),
                'certificateNumber' => $registration->certificate_number,
                'rewardsShippedAt' => $registration->rewards_shipped_at?->toIso8601String(),
                'progress' => $this->progress->progress($registration),
            ],
        ];
    }

    public static function marathonPayload(Marathon $marathon): array
    {
        return [
            'id' => (string) $marathon->id,
            'title' => $marathon->title,
            'description' => $marathon->description,
            'theme' => $marathon->theme,
            'themeData' => $marathon->theme_data,
            'kitImageUrl' => $marathon->kit_image_url,
            'distanceKm' => $marathon->distance_km,
            'price' => $marathon->price,
            'currency' => $marathon->currency,
            'startsAt' => $marathon->starts_at->toDateString(),
            'endsAt' => $marathon->ends_at->toDateString(),
            'phase' => $marathon->phase(),
            'registrationOpensAt' => $marathon->registration_opens_at?->toDateString(),
            'registrationClosesAt' => $marathon->registrationClosesOn()->toDateString(),
            'registrationStatus' => $marathon->registrationStatus(),
            'paymentInstructions' => $marathon->payment_instructions,
            'paymentQrUrl' => $marathon->payment_qr_url,
            'isPublished' => $marathon->is_published,
        ];
    }
}
