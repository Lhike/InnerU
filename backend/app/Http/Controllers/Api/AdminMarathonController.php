<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Marathon;
use App\Models\MarathonRegistration;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
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

        $marathon = Marathon::create($this->validated($request, creating: true) + [
            'created_by' => $request->user()->id,
        ]);

        return response()->json(['marathon' => MarathonController::marathonPayload($marathon->refresh())], Response::HTTP_CREATED);
    }

    public function update(Request $request, Marathon $marathon): JsonResponse
    {
        if ($denied = $this->denyUnlessAdmin($request)) {
            return $denied;
        }

        $marathon->fill($this->validated($request, creating: false))->save();

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

    private function validated(Request $request, bool $creating): array
    {
        $required = $creating ? 'required' : 'sometimes';

        return $request->validate([
            'title' => [$required, 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:5000'],
            'theme' => [$required, Rule::in(Marathon::THEMES)],
            'distance_km' => [$required, 'numeric', 'min:1', 'max:500'],
            'price' => [$required, 'numeric', 'min:0', 'max:100000'],
            'currency' => ['nullable', 'string', 'size:3'],
            'starts_at' => [$required, 'date'],
            'ends_at' => [$required, 'date', 'after_or_equal:starts_at'],
            'payment_instructions' => ['nullable', 'string', 'max:2000'],
            'is_published' => ['nullable', 'boolean'],
        ]);
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
