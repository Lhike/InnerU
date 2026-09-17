<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GoalApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_goal_creation_persists_the_provided_start_date(): void
    {
        $company = Company::create([
            'id' => (string) Str::uuid(),
            'name' => 'GoalCo',
            'code' => 'GOAL01',
        ]);

        $user = User::factory()->create([
            'company_id' => $company->id,
            'active_company_id' => $company->id,
        ]);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/goals', [
            'category' => 'PERSONAL',
            'title' => 'Plan the launch',
            'start_date' => '2026-07-01',
            'target_date' => '2026-09-01',
            'target_value' => 100,
            'current_value' => 25,
            'unit' => 'pts',
        ]);

        $response->assertCreated()
            ->assertJsonPath('goal.title', 'Plan the launch');

        $this->assertDatabaseHas('goals', [
            'user_id' => $user->id,
            'company_id' => $company->id,
            'start_date' => '2026-07-01',
            'target_date' => '2026-09-01',
        ]);
    }

    public function test_goal_payload_exposes_distinct_daily_and_weekly_targets(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-09-17 12:00:00', 'Asia/Manila'));
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/goals', [
            'category' => 'PROFESSIONAL',
            'title' => 'Build a skill',
            'target_date' => '2026-12-15',
            'target_value' => 34,
            'current_value' => 0,
            'unit' => 'KM',
            'target_period' => 'NONE',
        ])->assertCreated();

        $response->assertJsonPath('goal.dailyTarget', 0.38)
            ->assertJsonPath('goal.weeklyTarget', 2.66);

        Carbon::setTestNow();
    }
}
