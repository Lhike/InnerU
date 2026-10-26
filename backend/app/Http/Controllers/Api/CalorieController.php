<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CalorieDay;
use App\Models\CalorieEntry;
use App\Models\CalorieProfile;
use App\Models\FoodMemory;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\Response;

class CalorieController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $validated = $request->validate([
            'date' => ['nullable', 'date'],
        ]);

        $date = isset($validated['date'])
            ? Carbon::parse($validated['date'])->toDateString()
            : now()->toDateString();

        $day = $this->dayQuery($user->id, $date)->first();

        $profile = $this->profileFor($user);

        return response()->json([
            'day' => $day ? $this->dayPayload($day) : null,
            'entries' => $this->entriesForDay($user->id, $date),
            'defaultGoal' => $day?->daily_goal ?: $this->resolveGoal($user, $date),
            'profile' => $profile ? $this->profilePayload($profile) : null,
        ]);
    }

    public function history(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $validated = $request->validate([
            'limit' => ['nullable', 'integer', 'min:1', 'max:365'],
        ]);

        $limit = (int) ($validated['limit'] ?? 90);

        return response()->json([
            'days' => $this->dayQuery($user->id)
                ->limit($limit)
                ->get()
                ->map(fn (CalorieDay $day) => $this->dayPayload($day)),
        ]);
    }

    public function upsertDay(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $validated = $request->validate([
            'date' => ['nullable', 'date'],
            'daily_goal' => ['nullable', 'integer', 'min:1', 'max:10000'],
            'water_glasses' => ['nullable', 'integer', 'min:0', 'max:100'],
            'water_goal' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $date = isset($validated['date'])
            ? Carbon::parse($validated['date'])->toDateString()
            : now()->toDateString();

        $day = DB::transaction(function () use ($user, $date, $validated): CalorieDay {
            $existing = $this->dayQuery($user->id, $date)->first();
            $totals = $this->totalsForDay($user->id, $date);

            $day = CalorieDay::updateOrCreate(
                [
                    'user_id' => $user->id,
                    'date' => $date,
                ],
                [
                    'daily_goal' => $validated['daily_goal']
                        ?? $existing?->daily_goal
                        ?? $this->resolveGoal($user, $date),
                    'total_calories' => $totals['total_calories'],
                    'total_protein' => $totals['total_protein'],
                    'total_carbs' => $totals['total_carbs'],
                    'total_fat' => $totals['total_fat'],
                    'meal_count' => $totals['meal_count'],
                    'water_glasses' => $validated['water_glasses'] ?? $existing?->water_glasses ?? 0,
                    'water_goal' => $validated['water_goal'] ?? $existing?->water_goal ?? 8,
                ]
            );

            return $day->refresh();
        });

        return response()->json([
            'day' => $this->dayPayload($day),
        ]);
    }

    public function storeEntry(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $validated = $request->validate([
            'date' => ['nullable', 'date'],
            'meal' => ['required', 'string', 'max:255'],
            'meal_type' => ['required', 'string', 'max:120'],
            ...$this->entryNutritionRules(required: true),
            'photo_url' => ['nullable', 'string', 'max:2048'],
        ]);

        $date = isset($validated['date'])
            ? Carbon::parse($validated['date'])->toDateString()
            : now()->toDateString();

        $payload = DB::transaction(function () use ($user, $date, $validated): array {
            $day = CalorieDay::query()
                ->firstOrCreate([
                    'user_id' => $user->id,
                    'date' => $date,
                ], [
                    'daily_goal' => $this->resolveGoal($user, $date),
                    'water_glasses' => 0,
                    'water_goal' => 8,
                ]);

            $entry = CalorieEntry::create([
                'user_id' => $user->id,
                'calorie_day_id' => $day->id,
                'date' => $date,
                'meal' => trim($validated['meal']),
                'meal_type' => trim($validated['meal_type']),
                'calories' => $validated['calories'],
                'protein' => $validated['protein'] ?? 0,
                'carbs' => $validated['carbs'] ?? 0,
                'fat' => $validated['fat'] ?? 0,
                'quantity' => $validated['quantity'] ?? null,
                'measurement_unit' => $validated['measurement_unit'] ?? null,
                'photo_url' => $validated['photo_url'] ?? null,
            ]);

            $day = $this->refreshDayTotals($user, $date);

            return [
                'entry' => $this->entryPayload($entry),
                'day' => $this->dayPayload($day),
                'entries' => $this->entriesForDay($user->id, $date),
            ];
        });

        return response()->json($payload, Response::HTTP_CREATED);
    }

    public function updateEntry(Request $request, string $entryId): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $entry = $this->ownedEntry($user, $entryId);
        if ($entry === null) {
            return response()->json(['message' => 'Entry not found.'], Response::HTTP_NOT_FOUND);
        }

        $validated = $request->validate([
            'meal' => ['sometimes', 'string', 'max:255'],
            'meal_type' => ['sometimes', 'string', 'max:120'],
            ...$this->entryNutritionRules(required: false),
        ]);

        $date = $entry->date->toDateString();

        $payload = DB::transaction(function () use ($user, $entry, $validated, $date): array {
            $entry->fill(collect($validated)
                ->map(fn ($value, $key) => in_array($key, ['meal', 'meal_type'], true) ? trim($value) : $value)
                ->all())
                ->save();

            return [
                'entry' => $this->entryPayload($entry->refresh()),
                'day' => $this->dayPayload($this->refreshDayTotals($user, $date)),
                'entries' => $this->entriesForDay($user->id, $date),
            ];
        });

        return response()->json($payload);
    }

    public function destroyEntry(Request $request, string $entryId): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $entry = $this->ownedEntry($user, $entryId);
        if ($entry === null) {
            return response()->json(['message' => 'Entry not found.'], Response::HTTP_NOT_FOUND);
        }

        $date = $entry->date->toDateString();

        $payload = DB::transaction(function () use ($user, $entry, $date): array {
            $entry->delete();

            return [
                'day' => $this->dayPayload($this->refreshDayTotals($user, $date)),
                'entries' => $this->entriesForDay($user->id, $date),
            ];
        });

        return response()->json($payload);
    }

    public function showProfile(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $profile = $this->profileFor($user);

        return response()->json([
            'profile' => $profile ? $this->profilePayload($profile) : null,
        ]);
    }

    /**
     * Saves the body stats behind the calculator and the goal they produce,
     * so new days start from this goal instead of a flat 2000.
     */
    public function upsertProfile(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $validated = $request->validate([
            'sex' => ['nullable', Rule::in(['male', 'female'])],
            'age' => ['nullable', 'integer', 'min:13', 'max:100'],
            'height_cm' => ['nullable', 'numeric', 'min:100', 'max:250'],
            'weight_kg' => ['nullable', 'numeric', 'min:30', 'max:300'],
            'activity_level' => ['nullable', Rule::in(self::ACTIVITY_LEVELS)],
            'goal_type' => ['nullable', Rule::in(self::GOAL_TYPES)],
            'count_steps' => ['nullable', 'boolean'],
            'daily_goal' => ['nullable', 'integer', 'min:800', 'max:10000'],
            // Also apply the goal to this day (normally the client's today).
            'date' => ['nullable', 'date'],
        ]);

        $profile = CalorieProfile::updateOrCreate(
            ['user_id' => $user->id],
            collect($validated)->except('date')->all(),
        );

        $day = null;
        if (isset($validated['date'], $validated['daily_goal'])) {
            $date = Carbon::parse($validated['date'])->toDateString();
            $day = $this->refreshDayTotals($user, $date, $validated['daily_goal']);
        }

        return response()->json([
            'profile' => $this->profilePayload($profile->refresh()),
            'day' => $day ? $this->dayPayload($day) : null,
        ]);
    }

    /** Foods the user logs most recently, for one-tap re-logging. */
    public function indexFoodMemory(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $validated = $request->validate([
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $memories = FoodMemory::query()
            ->where('user_id', $user->id)
            ->whereNotNull('last_used_at')
            ->orderByDesc('last_used_at')
            ->orderByDesc('use_count')
            ->limit((int) ($validated['limit'] ?? 12))
            ->get()
            ->map(fn (FoodMemory $memory) => $this->foodMemoryPayload($memory));

        return response()->json(['memories' => $memories]);
    }

    public function showFoodMemory(Request $request, string $key): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $memory = FoodMemory::query()
            ->where('user_id', $user->id)
            ->where('key', $key)
            ->first();

        return response()->json([
            'memory' => $memory ? $this->foodMemoryPayload($memory) : null,
        ]);
    }

    public function upsertFoodMemory(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $validated = $request->validate([
            'key' => ['required', 'string', 'max:120'],
            'display_name' => ['required', 'string', 'max:255'],
            'lookup_name' => ['required', 'string', 'max:255'],
            'calories' => ['required', 'integer', 'min:1', 'max:100000'],
            'protein' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'carbs' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'fat' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'serving_quantity' => ['nullable', 'numeric', 'gt:0', 'max:100000'],
            'serving_unit' => ['nullable', 'string', 'max:50'],
            'grams_per_serving' => ['nullable', 'numeric', 'gt:0', 'max:100000'],
            'source' => ['nullable', 'string', 'max:120'],
            // True when the user actually logged this food, so it shows up
            // in their recent foods.
            'used' => ['nullable', 'boolean'],
        ]);

        $memory = DB::transaction(function () use ($user, $validated): FoodMemory {
            $memory = FoodMemory::query()->firstOrNew([
                'user_id' => $user->id,
                'key' => trim($validated['key']),
            ]);

            $memory->fill([
                'display_name' => trim($validated['display_name']),
                'lookup_name' => trim($validated['lookup_name']),
                'calories' => $validated['calories'],
                'protein' => $validated['protein'] ?? 0,
                'carbs' => $validated['carbs'] ?? 0,
                'fat' => $validated['fat'] ?? 0,
                'serving_quantity' => $validated['serving_quantity'] ?? null,
                'serving_unit' => isset($validated['serving_unit']) ? trim($validated['serving_unit']) : null,
                'grams_per_serving' => $validated['grams_per_serving'] ?? null,
                'source' => trim((string) ($validated['source'] ?? 'manual')),
            ]);

            if ($validated['used'] ?? false) {
                $memory->use_count = ($memory->use_count ?? 0) + 1;
                $memory->last_used_at = now();
            }

            $memory->save();

            return $memory;
        });

        return response()->json([
            'memory' => $this->foodMemoryPayload($memory),
        ]);
    }

    private const ACTIVITY_LEVELS = ['sedentary', 'light', 'moderate', 'active', 'very_active'];

    private const GOAL_TYPES = ['lose', 'lose_slow', 'maintain', 'gain_slow', 'gain'];

    private const FALLBACK_GOAL = 2000;

    /**
     * The goal a day starts with: the user's saved profile goal, else the
     * goal from their most recent earlier day, else the app default.
     */
    private function resolveGoal(User $user, string $date): int
    {
        $profileGoal = $this->profileFor($user)?->daily_goal;
        if ($profileGoal) {
            return $profileGoal;
        }

        $previous = CalorieDay::query()
            ->where('user_id', $user->id)
            ->whereDate('date', '<', $date)
            ->orderByDesc('date')
            ->value('daily_goal');

        return $previous ?: self::FALLBACK_GOAL;
    }

    private function profileFor(User $user): ?CalorieProfile
    {
        return CalorieProfile::query()->where('user_id', $user->id)->first();
    }

    private function ownedEntry(User $user, string $entryId): ?CalorieEntry
    {
        return CalorieEntry::query()
            ->where('user_id', $user->id)
            ->whereKey($entryId)
            ->first();
    }

    /** @return array<string, array<int, mixed>> */
    private function entryNutritionRules(bool $required): array
    {
        $presence = $required ? 'required' : 'sometimes';

        return [
            'calories' => [$presence, 'integer', 'min:1', 'max:100000'],
            'protein' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'carbs' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'fat' => ['nullable', 'integer', 'min:0', 'max:100000'],
            'quantity' => ['nullable', 'numeric', 'min:0', 'max:100000'],
            'measurement_unit' => ['nullable', 'string', 'max:50'],
        ];
    }

    /**
     * Recomputes a day's totals from its entries, creating the day (with the
     * resolved goal) if needed. [$goal] overrides the stored goal.
     */
    private function refreshDayTotals(User $user, string $date, ?int $goal = null): CalorieDay
    {
        $day = CalorieDay::query()->firstOrCreate([
            'user_id' => $user->id,
            'date' => $date,
        ], [
            'daily_goal' => $goal ?? $this->resolveGoal($user, $date),
            'water_glasses' => 0,
            'water_goal' => 8,
        ]);

        $day->forceFill($this->totalsForDay($user->id, $date) + [
            'daily_goal' => $goal ?? ($day->daily_goal ?: $this->resolveGoal($user, $date)),
            'water_glasses' => $day->water_glasses ?: 0,
            'water_goal' => $day->water_goal ?: 8,
        ])->save();

        return $day->refresh();
    }

    private function profilePayload(CalorieProfile $profile): array
    {
        return [
            'sex' => $profile->sex,
            'age' => $profile->age,
            'heightCm' => $profile->height_cm,
            'weightKg' => $profile->weight_kg,
            'activityLevel' => $profile->activity_level,
            'goalType' => $profile->goal_type,
            'countSteps' => $profile->count_steps,
            'dailyGoal' => $profile->daily_goal,
            'updatedAt' => $profile->updated_at?->toIso8601String(),
        ];
    }

    private function dayQuery(int|string $userId, ?string $date = null)
    {
        $query = CalorieDay::query()
            ->where('user_id', $userId);

        if ($date !== null) {
            $query->whereDate('date', $date);
        }

        return $query->orderByDesc('date')->orderByDesc('id');
    }

    private function entriesForDay(int|string $userId, string $date)
    {
        return CalorieEntry::query()
            ->where('user_id', $userId)
            ->whereDate('date', $date)
            ->orderByDesc('created_at')
            ->get()
            ->map(fn (CalorieEntry $entry) => $this->entryPayload($entry));
    }

    private function totalsForDay(int|string $userId, string $date): array
    {
        $entries = CalorieEntry::query()
            ->where('user_id', $userId)
            ->whereDate('date', $date)
            ->get();

        return [
            'total_calories' => $entries->sum('calories'),
            'total_protein' => $entries->sum('protein'),
            'total_carbs' => $entries->sum('carbs'),
            'total_fat' => $entries->sum('fat'),
            'meal_count' => $entries->count(),
        ];
    }

    private function dayPayload(CalorieDay $day): array
    {
        return [
            'id' => (string) $day->id,
            'userId' => (string) $day->user_id,
            'date' => $day->date?->toDateString(),
            'dailyGoal' => $day->daily_goal,
            'totalCalories' => $day->total_calories,
            'totalProtein' => $day->total_protein,
            'totalCarbs' => $day->total_carbs,
            'totalFat' => $day->total_fat,
            'mealCount' => $day->meal_count,
            'waterGlasses' => $day->water_glasses,
            'waterGoal' => $day->water_goal,
            'createdAt' => $day->created_at?->toIso8601String(),
            'updatedAt' => $day->updated_at?->toIso8601String(),
        ];
    }

    private function entryPayload(CalorieEntry $entry): array
    {
        return [
            'id' => (string) $entry->id,
            'meal' => $entry->meal,
            'mealType' => $entry->meal_type,
            'calories' => $entry->calories,
            'protein' => $entry->protein,
            'carbs' => $entry->carbs,
            'fat' => $entry->fat,
            'quantity' => $entry->quantity,
            'measurementUnit' => $entry->measurement_unit,
            'photoUrl' => $entry->photo_url,
            'createdAt' => $entry->created_at?->toIso8601String(),
        ];
    }

    private function foodMemoryPayload(FoodMemory $memory): array
    {
        return [
            'id' => (string) $memory->id,
            'key' => $memory->key,
            'displayName' => $memory->display_name,
            'lookupName' => $memory->lookup_name,
            'calories' => $memory->calories,
            'protein' => $memory->protein,
            'carbs' => $memory->carbs,
            'fat' => $memory->fat,
            'servingQuantity' => $memory->serving_quantity,
            'servingUnit' => $memory->serving_unit,
            'gramsPerServing' => $memory->grams_per_serving,
            'source' => $memory->source,
            'useCount' => $memory->use_count,
            'lastUsedAt' => $memory->last_used_at?->toIso8601String(),
            'createdAt' => $memory->created_at?->toIso8601String(),
            'updatedAt' => $memory->updated_at?->toIso8601String(),
        ];
    }
}
