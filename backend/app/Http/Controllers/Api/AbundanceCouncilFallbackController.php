<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
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

        $groupId = CoachMentee::query()
            ->where('mentee_id', (string) $user->id)
            ->whereNotNull('group_id')
            ->value('group_id');
        if ($groupId === null) {
            return response()->json(['councils' => [], 'members' => []]);
        }

        $group = CoachGroup::query()->find($groupId);
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

        return CoachGroup::query()
            ->where(function ($query) use ($companyId, $companyCode, $companyName): void {
                $hasScope = false;
                if ($companyId !== '') {
                    $query->where('company_id', $companyId);
                    $hasScope = true;
                }
                if ($companyCode !== '') {
                    if ($hasScope) {
                        $query->orWhere('company_code', $companyCode);
                    } else {
                        $query->where('company_code', $companyCode);
                    }
                    $hasScope = true;
                }
                if ($companyName !== '') {
                    if ($hasScope) {
                        $query->orWhere('company_name', $companyName);
                    } else {
                        $query->where('company_name', $companyName);
                    }
                    $hasScope = true;
                }
                if (! $hasScope) {
                    $query->whereNotNull('id');
                }
            })
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
