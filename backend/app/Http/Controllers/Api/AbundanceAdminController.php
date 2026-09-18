<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CoachMentee;
use App\Models\Goal;
use App\Models\GoalTask;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

class AbundanceAdminController extends Controller
{
    private const COMPANY = 'ABU15DN';

    public function index(Request $request): JsonResponse
    {
        if (($response = $this->authorizeAdmin($request)) !== null) return $response;

        $users = $this->abundanceUsers()->get();
        $coaches = $users->filter(fn (User $user) => $this->isCoach($user))->values();
        $students = $users->filter(fn (User $user) => !$this->isCoach($user) && !$this->isAdmin($user))->values();
        $assignments = CoachMentee::query()->whereIn('coach_id', $coaches->pluck('id'))->get()->groupBy('coach_id');

        return response()->json([
            'companyCode' => self::COMPANY,
            'coaches' => $coaches->map(fn (User $coach) => $this->mapUser($coach, $assignments->get($coach->id, collect())))->values(),
            'students' => $students->map(fn (User $student) => $this->mapStudent($student))->values(),
        ]);
    }

    public function assign(Request $request): JsonResponse
    {
        if (($response = $this->authorizeAdmin($request)) !== null) return $response;
        $validated = $request->validate(['coach_id' => ['required', 'integer'], 'student_id' => ['required', 'integer']]);
        $coach = $this->eligibleCoach((int) $validated['coach_id']);
        $student = $this->eligibleStudent((int) $validated['student_id']);
        if ($coach === null || $student === null) return $this->forbidden();

        DB::transaction(function () use ($coach, $student): void {
            CoachMentee::query()->where('mentee_id', (string) $student->id)->delete();
            CoachMentee::create([
                'coach_id' => (string) $coach->id,
                'mentee_id' => (string) $student->id,
                'mentee_name' => $student->name,
                'mentee_email' => $student->email,
                'team_name' => 'Abundance',
            ]);
        });

        return response()->json(['assignment' => ['coachId' => (string) $coach->id, 'studentId' => (string) $student->id]]);
    }

    public function remove(Request $request, int $studentId): JsonResponse
    {
        if (($response = $this->authorizeAdmin($request)) !== null) return $response;
        if ($this->eligibleStudent($studentId) === null) return $this->forbidden();
        CoachMentee::query()->where('mentee_id', (string) $studentId)->delete();
        return response()->json(['message' => 'Student removed from coach.']);
    }

    public function updateGoal(Request $request, string $goalId): JsonResponse
    {
        if (($response = $this->authorizeAdmin($request)) !== null) return $response;
        $goal = Goal::query()->find($goalId);
        if ($goal === null || $this->eligibleStudent((int) $goal->user_id) === null) return $this->forbidden();
        $validated = $request->validate([
            'title' => ['sometimes', 'string', 'max:255'], 'description' => ['sometimes', 'nullable', 'string'],
            'notes' => ['sometimes', 'nullable', 'string'], 'status' => ['sometimes', 'string', 'max:32'],
            'target_date' => ['sometimes', 'date'], 'start_date' => ['sometimes', 'date'],
            'target_value' => ['sometimes', 'numeric', 'min:0'], 'current_value' => ['sometimes', 'numeric', 'min:0'],
        ]);
        $target = (float) ($validated['target_value'] ?? $goal->target_value);
        $current = (float) ($validated['current_value'] ?? $goal->current_value);
        $status = strtoupper((string) ($validated['status'] ?? $goal->status));
        $goal->fill($validated);
        $goal->status = $status;
        $goal->target_value = $target;
        $goal->current_value = $current;
        $goal->progress = $status === 'COMPLETED' ? 100 : ($target > 0 ? (int) round(min(100, max(0, $current / $target * 100))) : 0);
        if (isset($validated['start_date'])) $goal->start_date = Carbon::parse($validated['start_date'])->toDateString();
        if (isset($validated['target_date'])) $goal->target_date = Carbon::parse($validated['target_date'])->toDateString();
        $goal->save();
        return response()->json(['goal' => $this->mapGoal($goal->refresh())]);
    }

    public function storeTask(Request $request, string $goalId): JsonResponse
    {
        if (($response = $this->authorizeAdmin($request)) !== null) return $response;
        $goal = Goal::query()->find($goalId);
        if ($goal === null || $this->eligibleStudent((int) $goal->user_id) === null) return $this->forbidden();
        $validated = $request->validate(['title' => ['required', 'string', 'max:255']]);
        $task = GoalTask::create([
            'id' => (string) Str::uuid(), 'goal_id' => $goal->id, 'title' => trim($validated['title']),
            'status' => 'NOT_STARTED', 'is_complete' => false,
            'sort_order' => GoalTask::query()->where('goal_id', $goal->id)->count(), 'weight' => 1,
        ]);
        $this->syncMilestone($goal);
        return response()->json(['task' => $this->mapTask($task)], Response::HTTP_CREATED);
    }

    private function authorizeAdmin(Request $request): ?JsonResponse
    {
        $user = $request->user();
        return $user instanceof User && $this->isAdmin($user) && $this->isAbundance($user) ? null : $this->forbidden();
    }

    private function forbidden(): JsonResponse { return response()->json(['message' => 'Abundance admin access required.'], Response::HTTP_FORBIDDEN); }
    private function isAbundance(User $user): bool { return strtoupper(trim((string) ($user->active_company_code ?: $user->company_code))) === self::COMPANY || strtoupper(trim((string) $user->company_code)) === self::COMPANY; }
    private function isAdmin(User $user): bool { return strtolower(trim((string) $user->role)) === 'admin' || (bool) $user->is_admin; }
    private function isCoach(User $user): bool { return strtolower(trim((string) $user->role)) === 'coach' || (bool) $user->is_coach; }
    private function abundanceUsers() { return User::query()->where(function ($query): void { $query->where('company_code', self::COMPANY)->orWhere('active_company_code', self::COMPANY); }); }
    private function eligibleCoach(int $id): ?User { $user = $this->abundanceUsers()->find($id); return $user && $this->isCoach($user) && !$this->isAdmin($user) ? $user : null; }
    private function eligibleStudent(int $id): ?User { $user = $this->abundanceUsers()->find($id); return $user && !$this->isCoach($user) && !$this->isAdmin($user) ? $user : null; }
    private function mapUser(User $user, $relations): array { return array_merge($this->mapStudent($user), ['students' => $relations->map(fn (CoachMentee $r) => ['id' => (string) $r->mentee_id, 'name' => $r->mentee_name, 'email' => $r->mentee_email])->values()]); }
    private function mapStudent(User $user): array {
        $assignment = CoachMentee::query()->where('mentee_id', (string) $user->id)->first();
        $goals = Goal::query()->where('user_id', $user->id)->orderBy('target_date')->get();
        return ['id' => (string) $user->id, 'name' => $user->name, 'email' => $user->email, 'username' => $user->number, 'coachId' => $assignment?->coach_id, 'goals' => $goals->map(fn (Goal $goal) => ['id' => (string) $goal->id, 'title' => $goal->title, 'status' => $goal->status, 'progress' => (int) $goal->progress, 'tasks' => GoalTask::query()->where('goal_id', $goal->id)->orderBy('sort_order')->get()->map(fn (GoalTask $task) => ['id' => (string) $task->id, 'title' => $task->title, 'status' => $task->status])->values()])->values()];
    }
    private function mapGoal(Goal $goal): array { return ['id' => (string) $goal->id, 'title' => $goal->title, 'status' => $goal->status, 'progress' => (int) $goal->progress, 'targetValue' => (float) $goal->target_value, 'currentValue' => (float) $goal->current_value, 'targetDate' => $goal->target_date?->toIso8601String()]; }
    private function mapTask(GoalTask $task): array { return ['id' => (string) $task->id, 'goalId' => (string) $task->goal_id, 'title' => $task->title, 'status' => $task->status, 'isComplete' => (bool) $task->is_complete]; }
    private function syncMilestone(Goal $goal): void { if ($goal->goal_type !== 'MILESTONE') return; $tasks = GoalTask::query()->where('goal_id', $goal->id)->get(); $goal->progress = $tasks->isEmpty() ? 0 : (int) round($tasks->avg(fn (GoalTask $task) => $task->status === 'DONE' ? 100 : ($task->status === 'IN_PROGRESS' ? 50 : 0))); $goal->save(); }
}
