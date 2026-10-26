<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CalorieTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_manage_calorie_days_entries_and_food_memory(): void
    {
        $user = User::factory()->create([
            'name' => 'Calorie User',
            'email' => 'calorie@example.com',
            'company_code' => 'ABC',
            'company_name' => 'ABC',
        ]);

        Sanctum::actingAs($user);

        $goal = $this->postJson('/api/calorie/day', [
            'date' => '2026-07-21',
            'daily_goal' => 2200,
            'water_glasses' => 3,
            'water_goal' => 8,
        ]);

        $goal->assertOk()
            ->assertJsonPath('day.dailyGoal', 2200)
            ->assertJsonPath('day.waterGlasses', 3);

        $entry = $this->postJson('/api/calorie/entries', [
            'date' => '2026-07-21',
            'meal' => 'Chicken Rice',
            'meal_type' => 'Lunch',
            'calories' => 650,
            'protein' => 40,
            'carbs' => 70,
            'fat' => 12,
            'quantity' => 1,
            'measurement_unit' => 'plate',
            'photo_url' => 'https://example.com/photo.jpg',
        ]);

        $entry->assertCreated()
            ->assertJsonPath('day.totalCalories', 650)
            ->assertJsonPath('entries.0.meal', 'Chicken Rice');

        $this->assertDatabaseHas('calorie_days', [
            'user_id' => $user->id,
            'date' => '2026-07-21',
            'daily_goal' => 2200,
            'total_calories' => 650,
            'water_glasses' => 3,
        ]);

        $history = $this->getJson('/api/calorie/history?limit=10');
        $history->assertOk()
            ->assertJsonCount(1, 'days')
            ->assertJsonPath('days.0.totalCalories', 650);

        $show = $this->getJson('/api/calorie?date=2026-07-21');
        $show->assertOk()
            ->assertJsonPath('day.dailyGoal', 2200)
            ->assertJsonCount(1, 'entries');

        $memory = $this->postJson('/api/calorie/food-memory', [
            'key' => 'chicken_rice',
            'display_name' => 'Chicken Rice',
            'lookup_name' => 'chicken rice',
            'calories' => 650,
            'protein' => 40,
            'carbs' => 70,
            'fat' => 12,
            'source' => 'online_lookup',
        ]);

        $memory->assertOk()
            ->assertJsonPath('memory.key', 'chicken_rice');

        $lookup = $this->getJson('/api/calorie/food-memory/chicken_rice');
        $lookup->assertOk()
            ->assertJsonPath('memory.displayName', 'Chicken Rice');
    }

    private function makeUser(string $email): User
    {
        return User::factory()->create([
            'name' => 'Calorie User',
            'email' => $email,
        ]);
    }

    private function logEntry(string $date, int $calories, string $meal = 'Adobo'): \Illuminate\Testing\TestResponse
    {
        return $this->postJson('/api/calorie/entries', [
            'date' => $date,
            'meal' => $meal,
            'meal_type' => 'Lunch',
            'calories' => $calories,
            'protein' => 20,
            'carbs' => 10,
            'fat' => 15,
        ]);
    }

    public function test_a_new_day_keeps_the_goal_from_the_previous_day(): void
    {
        Sanctum::actingAs($this->makeUser('carry@example.com'));

        $this->postJson('/api/calorie/day', ['date' => '2026-10-20', 'daily_goal' => 1700])
            ->assertOk();

        $this->getJson('/api/calorie?date=2026-10-21')
            ->assertOk()
            ->assertJsonPath('day', null)
            ->assertJsonPath('defaultGoal', 1700);

        $this->logEntry('2026-10-21', 300)
            ->assertCreated()
            ->assertJsonPath('day.dailyGoal', 1700);
    }

    public function test_the_saved_profile_goal_wins_and_can_be_applied_to_today(): void
    {
        Sanctum::actingAs($this->makeUser('profile@example.com'));

        $this->postJson('/api/calorie/day', ['date' => '2026-10-20', 'daily_goal' => 2500]);

        $this->postJson('/api/calorie/profile', [
            'sex' => 'female',
            'age' => 30,
            'height_cm' => 160,
            'weight_kg' => 60.5,
            'activity_level' => 'sedentary',
            'goal_type' => 'lose',
            'count_steps' => true,
            'daily_goal' => 1400,
            'date' => '2026-10-21',
        ])
            ->assertOk()
            ->assertJsonPath('profile.weightKg', 60.5)
            ->assertJsonPath('profile.goalType', 'lose')
            ->assertJsonPath('day.dailyGoal', 1400);

        $this->getJson('/api/calorie?date=2026-10-22')
            ->assertJsonPath('defaultGoal', 1400)
            ->assertJsonPath('profile.countSteps', true);

        $this->postJson('/api/calorie/profile', ['weight_kg' => 5])->assertStatus(422);
        $this->postJson('/api/calorie/profile', ['goal_type' => 'bulk'])->assertStatus(422);
    }

    public function test_entries_can_be_edited_and_deleted_and_totals_follow(): void
    {
        Sanctum::actingAs($this->makeUser('edit@example.com'));

        $first = $this->logEntry('2026-10-21', 500)->json('entry.id');
        $this->logEntry('2026-10-21', 200, 'Rice');

        $this->patchJson("/api/calorie/entries/{$first}", [
            'calories' => 350,
            'quantity' => 0.5,
            'measurement_unit' => 'serving',
        ])
            ->assertOk()
            ->assertJsonPath('entry.calories', 350)
            ->assertJsonPath('day.totalCalories', 550);

        $this->deleteJson("/api/calorie/entries/{$first}")
            ->assertOk()
            ->assertJsonPath('day.totalCalories', 200)
            ->assertJsonPath('day.mealCount', 1)
            ->assertJsonCount(1, 'entries');
    }

    public function test_users_cannot_touch_someone_elses_entries(): void
    {
        Sanctum::actingAs($this->makeUser('owner@example.com'));
        $entryId = $this->logEntry('2026-10-21', 500)->json('entry.id');

        Sanctum::actingAs($this->makeUser('intruder@example.com'));
        $this->patchJson("/api/calorie/entries/{$entryId}", ['calories' => 1])->assertNotFound();
        $this->deleteJson("/api/calorie/entries/{$entryId}")->assertNotFound();

        $this->assertDatabaseHas('calorie_entries', ['id' => $entryId, 'calories' => 500]);
    }

    public function test_food_memory_keeps_servings_and_lists_recent_foods(): void
    {
        Sanctum::actingAs($this->makeUser('recent@example.com'));

        $remember = fn (string $key, bool $used) => $this->postJson('/api/calorie/food-memory', [
            'key' => $key,
            'display_name' => ucfirst($key),
            'lookup_name' => $key,
            'calories' => 130,
            'serving_quantity' => 100,
            'serving_unit' => 'g',
            'grams_per_serving' => 100,
            'source' => 'meal_log',
            'used' => $used,
        ])->assertOk();

        $remember('rice', true);
        $remember('lookup_only', false);
        $this->travel(1)->minutes();
        $remember('adobo', true);
        $remember('rice', true)->assertJsonPath('memory.useCount', 2);

        $this->getJson('/api/calorie/food-memory?limit=5')
            ->assertOk()
            ->assertJsonCount(2, 'memories')
            ->assertJsonPath('memories.0.key', 'rice')
            ->assertJsonPath('memories.0.servingQuantity', 100)
            ->assertJsonPath('memories.0.servingUnit', 'g');
    }
}
