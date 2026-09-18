<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\LeaderboardController;
use App\Models\CoachGroup;
use App\Models\CoachMentee;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

/**
 * Compatibility surface for the A12 mobile Guild routes.
 *
 * A12 is the source of truth when the bridge is configured. During rollout,
 * however, an InnerU API deployment may receive the mobile request before the
 * bridge secret or A12 service is available. These routes expose the same
 * response shape using the coach_groups/coach_mentees tables already owned by
 * InnerU, so the Guild page remains usable instead of failing open.
 */
class AbundanceCouncilFallbackController extends Controller
{
    public function councils(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user instanceof User) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }
        $currentGroupId = CoachMentee::query()
            ->where('mentee_id', (string) $user->id)
            ->whereNotNull('group_id')
            ->value('group_id');

        $councils = $this->groupsForUser($user)
            ->map(fn (CoachGroup $group): array => $this->councilPayload($group, $currentGroupId))
            ->values();

        return response()->json(['councils' => $councils]);
    }

    public function guild(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user instanceof User) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }
        // Abundance Guild is a company-wide directory, not a council
        // membership surface. The A12 API normally owns this response; this
        // InnerU fallback preserves the same contract when the bridge is
        // unavailable.
        if ($this->isAbundanceUser($user)) {
            $leaderboard = app(LeaderboardController::class)
                ->index($request)
                ->getData(true);
            $entries = collect($leaderboard['entries'] ?? []);
            $users = $entries->reject(fn (array $entry): bool => ($entry['isCoach'] ?? false) === true)->values();
            $payload = [
                'company' => 'ABU15DN',
                'users' => $users,
            ];
            if ((bool) $user->is_coach) {
                $payload['coaches'] = $entries->filter(fn (array $entry): bool => ($entry['isCoach'] ?? false) === true)->values();
            }

            return response()->json($payload);
        }

        $groupId = CoachMentee::query()
            ->where('mentee_id', (string) $user->id)
            ->whereNotNull('group_id')
            ->value('group_id');
        if ($groupId === null) {
            return response()->json(['councils' => [], 'members' => []]);
        }

        // Re-apply the active company boundary when resolving an existing
        // assignment. A stale or imported coach_mentees row must not expose
        // a council owned by another company.
        $group = $this->groupsForUser($user)
            ->firstWhere('id', (string) $groupId);
        if ($group === null) {
            return response()->json(['councils' => [], 'members' => []]);
        }

        return response()->json([
            'councils' => [$this->councilPayload($group, (string) $group->id)],
            'members' => $this->memberPayload($group),
        ]);
    }

    public function join(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user instanceof User) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }
        if ($this->isAbundanceUser($user)) {
            return response()->json(['message' => 'Abundance coach assignments are managed by an admin.'], Response::HTTP_FORBIDDEN);
        }

        $validated = $request->validate(['councilId' => ['required', 'string']]);
        $group = CoachGroup::query()->find($validated['councilId']);
        if ($group === null || ! $this->groupsForUser($user)->contains('id', $group->id)) {
            return response()->json(['message' => 'Council not found.'], Response::HTTP_NOT_FOUND);
        }

        $coachIds = $this->groupCoachIds($group);
        DB::transaction(function () use ($coachIds, $group, $user): void {
            foreach ($coachIds as $coachId) {
                $relation = CoachMentee::query()
                    ->where('coach_id', $coachId)
                    ->where('mentee_id', (string) $user->id)
                    ->first();

                if ($relation === null) {
                    CoachMentee::query()->create([
                        'coach_id' => $coachId,
                        'mentee_id' => (string) $user->id,
                        'mentee_name' => $user->name,
                        'mentee_email' => $user->email,
                        'group_id' => (string) $group->id,
                        'group_name' => $group->name,
                    ]);
                    continue;
                }

                $relation->forceFill([
                    'mentee_name' => $user->name,
                    'mentee_email' => $user->email,
                    'group_id' => (string) $group->id,
                    'group_name' => $group->name,
                ])->save();
            }
        });

        return response()->json(['ok' => true]);
    }

    public function leave(Request $request): JsonResponse
    {
        $user = $request->user();
        if (! $user instanceof User) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }
        if ($this->isAbundanceUser($user)) {
            return response()->json(['message' => 'Abundance coach assignments are managed by an admin.'], Response::HTTP_FORBIDDEN);
        }

        CoachMentee::query()
            ->where('mentee_id', (string) $user->id)
            ->whereNotNull('group_id')
            ->update(['group_id' => null, 'group_name' => null]);

        return response()->json(['ok' => true]);
    }

    /** @return \Illuminate\Support\Collection<int, CoachGroup> */
    private function groupsForUser(User $user)
    {
        $companyId = $this->activeValue($user->active_company_id, $user->company_id);
        $companyCode = $this->activeValue($user->active_company_code, $user->company_code);
        $companyName = $this->activeValue($user->active_company_name, $user->company_name);

        // A user without a company must never receive another company's
        // councils. This is deliberately an empty query rather than an
        // unscoped fallback, because the endpoint is company-partitioned.
        if ($companyId === '' && $companyCode === '' && $companyName === '') {
            return CoachGroup::query()->whereRaw('1 = 0')->get();
        }

        $query = CoachGroup::query();
        if ($companyId !== '') {
            // The ID is authoritative. Keep the code fallback only for
            // legacy rows created before coach_groups gained company_id.
            $query->where(function ($scope) use ($companyId, $companyCode): void {
                $scope->where('company_id', $companyId);
                if ($companyCode !== '') {
                    $scope->orWhere(function ($legacy) use ($companyCode): void {
                        $legacy->where(function ($missingId): void {
                            $missingId->whereNull('company_id')->orWhere('company_id', '');
                        })->where('company_code', $companyCode);
                    });
                }
            });
        } elseif ($companyCode !== '') {
            $query->where('company_code', $companyCode);
        } else {
            // A name is only a last-resort legacy key, and must not override
            // a group carrying another company's ID or code.
            $query->where('company_name', $companyName)
                ->where(function ($scope): void {
                    $scope->whereNull('company_id')->orWhere('company_id', '');
                })->where(function ($scope): void {
                    $scope->whereNull('company_code')->orWhere('company_code', '');
                });
        }

        return $query
            ->orderBy('name')
            ->get();
    }

    private function councilPayload(CoachGroup $group, ?string $currentGroupId): array
    {
        $memberIds = $this->memberIds($group);
        $coachIds = $this->groupCoachIds($group);
        $coachName = User::query()->whereIn('id', $coachIds)->orderBy('name')->value('name');
        $averageScore = (int) round((float) (User::query()->whereIn('id', $memberIds)->avg('score') ?? 0));

        return [
            'id' => (string) $group->id,
            'name' => (string) $group->name,
            'description' => null,
            'coachName' => (string) ($coachName ?? ''),
            'memberCount' => count($memberIds),
            'averageScore' => $averageScore,
            'isCurrent' => $currentGroupId !== null && (string) $currentGroupId === (string) $group->id,
        ];
    }

    private function memberPayload(CoachGroup $group): array
    {
        $users = User::query()->whereIn('id', $this->memberIds($group))->orderByDesc('score')->get();
        return $users->map(fn (User $member): array => [
            'id' => (string) $member->id,
            'name' => (string) $member->name,
            'score' => (int) ($member->score ?? 0),
        ])->values()->all();
    }

    private function isAbundanceUser(User $user): bool
    {
        return in_array(strtoupper(trim((string) ($user->company_code ?: $user->active_company_code))), ['ABU15DN'], true);
    }

    /** @return array<int, string> */
    private function memberIds(CoachGroup $group): array
    {
        $ids = CoachMentee::query()
            ->where('group_id', (string) $group->id)
            ->pluck('mentee_id')
            ->map(static fn ($id): string => (string) $id)
            ->all();
        foreach (is_array($group->member_ids) ? $group->member_ids : [] as $id) {
            $ids[] = (string) $id;
        }
        return array_values(array_unique(array_filter($ids)));
    }

    /** @return array<int, string> */
    private function groupCoachIds(CoachGroup $group): array
    {
        $ids = [(string) $group->coach_id];
        foreach (is_array($group->coach_ids) ? $group->coach_ids : [] as $id) {
            $ids[] = (string) $id;
        }
        return array_values(array_unique(array_filter($ids)));
    }

    private function activeValue(?string $primary, ?string $fallback): string
    {
        return trim((string) ($primary ?: $fallback ?: ''));
    }
}
