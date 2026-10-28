<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Marathon;
use App\Models\MarathonRegistration;
use App\Models\User;
use App\Services\MarathonThemeGenerator;
use Illuminate\Http\Client\RequestException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\Response;

/** Admins create marathons and review runners' payments. */
class AdminMarathonController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        if ($denied = $this->denyUnlessAdmin($request)) {
            return $denied;
        }

        $marathons = Marathon::query()
            ->withCount([
                'registrations',
                'registrations as pending_review_count' => fn ($q) => $q->where('status', 'payment_submitted'),
                'registrations as confirmed_count' => fn ($q) => $q->where('status', 'confirmed'),
            ])
            ->orderByDesc('starts_at')
            ->get()
            ->map(fn (Marathon $m) => MarathonController::marathonPayload($m) + [
                'registrationCount' => $m->registrations_count,
                'pendingReviewCount' => $m->pending_review_count,
                'confirmedCount' => $m->confirmed_count,
            ]);

        return response()->json(['marathons' => $marathons]);
    }

    public function store(Request $request): JsonResponse
    {
        if ($denied = $this->denyUnlessAdmin($request)) {
            return $denied;
        }

        $marathon = Marathon::create($this->validated($request, null) + [
            'created_by' => $request->user()->id,
        ]);

        return response()->json(['marathon' => MarathonController::marathonPayload($marathon->refresh())], Response::HTTP_CREATED);
    }

    public function update(Request $request, Marathon $marathon): JsonResponse
    {
        if ($denied = $this->denyUnlessAdmin($request)) {
            return $denied;
        }

        $marathon->fill($this->validated($request, $marathon))->save();

        return response()->json(['marathon' => MarathonController::marathonPayload($marathon->refresh())]);
    }

    /** Removes the marathon with its registrations. */
    public function destroy(Request $request, Marathon $marathon): JsonResponse
    {
        if ($denied = $this->denyUnlessAdmin($request)) {
            return $denied;
        }

        $marathon->delete();

        return response()->json(['deleted' => true]);
    }

    /** Asks the AI for a theme (colours and kit) from the admin's idea. */
    public function suggestTheme(Request $request, MarathonThemeGenerator $ai): JsonResponse
    {
        if ($denied = $this->denyUnlessAdmin($request)) {
            return $denied;
        }
        $validated = $request->validate(['prompt' => ['required', 'string', 'min:2', 'max:200']]);
        if (! $ai->configured()) {
            return $this->aiNotSetUp();
        }

        try {
            return response()->json(['theme' => $ai->theme($validated['prompt'])]);
        } catch (RequestException $e) {
            report($e);

            return $this->aiFailed($e);
        }
    }

    /** Asks the AI to draw the kit of a theme it made. */
    public function kitImage(Request $request, MarathonThemeGenerator $ai): JsonResponse
    {
        if ($denied = $this->denyUnlessAdmin($request)) {
            return $denied;
        }
        $validated = $request->validate([
            'prompt' => ['required', 'string', 'min:2', 'max:200'],
            ...$this->themeDataRules('required'),
        ]);
        if (! $ai->configured()) {
            return $this->aiNotSetUp();
        }

        try {
            return response()->json([
                'kitImageUrl' => $ai->kitImage(MarathonThemeGenerator::sanitize($validated['theme_data'], $validated['prompt']), $validated['prompt']),
            ]);
        } catch (RequestException $e) {
            report($e);

            return $this->aiFailed($e);
        } catch (\RuntimeException $e) {
            report($e);

            return response()->json(['message' => 'The AI could not draw the kit. Try again.'], Response::HTTP_BAD_GATEWAY);
        }
    }

    public function registrations(Request $request, Marathon $marathon): JsonResponse
    {
        if ($denied = $this->denyUnlessAdmin($request)) {
            return $denied;
        }

        $registrations = $marathon->registrations()
            ->orderByRaw("CASE WHEN status = 'payment_submitted' THEN 0 ELSE 1 END")
            ->orderByDesc('updated_at')
            ->get()
            ->map(fn (MarathonRegistration $r) => [
                'id' => (string) $r->id,
                'userId' => (string) $r->user_id,
                'fullName' => $r->full_name,
                'email' => $r->email,
                'phone' => $r->phone,
                'shirtSize' => $r->shirt_size,
                'shippingAddress' => $r->shipping_address,
                'status' => $r->status,
                'paymentReference' => $r->payment_reference,
                'paymentProofUrl' => $r->payment_proof_url,
                'paymentSubmittedAt' => $r->payment_submitted_at?->toIso8601String(),
                'rejectionReason' => $r->rejection_reason,
                'bibNumber' => $r->bib_number,
                'finishedAt' => $r->finished_at?->toIso8601String(),
                'certificateNumber' => $r->certificate_number,
                'rewardsShippedAt' => $r->rewards_shipped_at?->toIso8601String(),
            ]);

        return response()->json(['registrations' => $registrations]);
    }

    public function review(Request $request, MarathonRegistration $registration): JsonResponse
    {
        if ($denied = $this->denyUnlessAdmin($request)) {
            return $denied;
        }

        $validated = $request->validate([
            'action' => ['required', Rule::in(['approve', 'reject', 'mark_shipped'])],
            'reason' => ['nullable', 'required_if:action,reject', 'string', 'max:255'],
        ]);

        if ($validated['action'] === 'mark_shipped') {
            if ($registration->finished_at === null) {
                return response()->json(['message' => 'Only finishers receive the shirt and medal.'], Response::HTTP_UNPROCESSABLE_ENTITY);
            }
            $registration->forceFill(['rewards_shipped_at' => now()])->save();
        } elseif ($validated['action'] === 'approve') {
            DB::transaction(fn () => MarathonController::confirm($registration, (int) $request->user()->id));
        } else {
            $registration->forceFill([
                'status' => 'rejected',
                'rejection_reason' => $validated['reason'],
                'reviewed_by' => $request->user()->id,
                'reviewed_at' => now(),
            ])->save();
        }

        return response()->json(['status' => $registration->refresh()->status, 'bibNumber' => $registration->bib_number]);
    }

    private function validated(Request $request, ?Marathon $marathon): array
    {
        $required = $marathon === null ? 'required' : 'sometimes';

        $validated = $request->validate([
            'title' => [$required, 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:5000'],
            'theme' => [$required, Rule::in(Marathon::THEMES)],
            ...$this->themeDataRules('required_if:theme,custom'),
            'kit_image_url' => ['nullable', 'url', 'max:2048'],
            'distance_km' => [$required, 'numeric', 'min:1', 'max:500'],
            'price' => [$required, 'numeric', 'min:0', 'max:100000'],
            'currency' => ['nullable', 'string', 'size:3'],
            'starts_at' => [$required, 'date'],
            'ends_at' => [$required, 'date', 'after_or_equal:starts_at'],
            'registration_opens_at' => ['nullable', 'date'],
            'registration_closes_at' => ['nullable', 'date'],
            'payment_instructions' => ['nullable', 'string', 'max:2000'],
            'payment_qr_url' => ['nullable', 'url', 'max:2048'],
            'is_published' => ['nullable', 'boolean'],
        ]);

        // Only a custom theme keeps its own colours.
        if (array_key_exists('theme', $validated) && $validated['theme'] !== 'custom') {
            $validated['theme_data'] = null;
        }

        $date = fn (string $key) => array_key_exists($key, $validated)
            ? ($validated[$key] === null ? null : Carbon::parse($validated[$key]))
            : $marathon?->{$key};
        $opens = $date('registration_opens_at');
        $closes = $date('registration_closes_at');
        $ends = $date('ends_at');
        $errors = [];
        if ($opens !== null && $closes !== null && $closes->lt($opens)) {
            $errors['registration_closes_at'] = 'Registration must close on or after it opens.';
        }
        if ($closes !== null && $ends !== null && $closes->gt($ends)) {
            $errors['registration_closes_at'] = 'Registration must close by the last day of the race.';
        }
        if ($opens !== null && $ends !== null && $opens->gt($ends)) {
            $errors['registration_opens_at'] = 'Registration must open before the race ends.';
        }
        if ($errors !== []) {
            throw ValidationException::withMessages($errors);
        }

        return $validated;
    }

    /** Rules for an AI-made theme sent as theme_data. */
    private function themeDataRules(string $presence): array
    {
        $hex = ['required_with:theme_data', 'string', 'regex:/\A#[0-9A-Fa-f]{6}\z/'];

        return [
            'theme_data' => ['nullable', $presence, 'array'],
            'theme_data.name' => ['required_with:theme_data', 'string', 'max:40'],
            'theme_data.emoji' => ['nullable', 'string', 'max:16'],
            'theme_data.tagline' => ['nullable', 'string', 'max:300'],
            'theme_data.gradient' => ['required_with:theme_data', 'array', 'size:2'],
            'theme_data.gradient.*' => ['string', 'regex:/\A#[0-9A-Fa-f]{6}\z/'],
            'theme_data.kitTop' => $hex,
            'theme_data.kitBottom' => $hex,
            'theme_data.kitShoes' => $hex,
            'theme_data.top' => ['nullable', Rule::in(Marathon::KIT_TOPS)],
            'theme_data.accessory' => ['nullable', Rule::in(Marathon::KIT_ACCESSORIES)],
            'theme_data.prompt' => ['nullable', 'string', 'max:200'],
        ];
    }

    private function aiNotSetUp(): JsonResponse
    {
        return response()->json([
            'message' => 'AI themes are not set up yet. Add OPENAI_API_KEY to the server .env.',
        ], Response::HTTP_SERVICE_UNAVAILABLE);
    }

    private function aiFailed(RequestException $e): JsonResponse
    {
        $reason = $e->response->json('error.message');

        return response()->json([
            'message' => 'The AI could not make a theme right now. Try again.'
                .(is_string($reason) && $reason !== '' ? " ({$reason})" : ''),
        ], Response::HTTP_BAD_GATEWAY);
    }

    private function denyUnlessAdmin(Request $request): ?JsonResponse
    {
        /** @var User|null $user */
        $user = $request->user();
        $role = strtolower(trim((string) $user?->role));
        if ($user === null || ! ($role === 'admin' || $user->is_admin)) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_FORBIDDEN);
        }

        return null;
    }
}
