<?php

namespace Tests\Feature;

use App\Models\CoachMentee;
use App\Models\Goal;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AbundanceAdminManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_abundance_admin_can_assign_reassign_and_remove_only_abundance_students(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'is_admin' => true, 'company_code' => 'ABU15DN']);
        $coachOne = User::factory()->create(['role' => 'coach', 'is_coach' => true, 'company_code' => 'ABU15DN']);
        $coachTwo = User::factory()->create(['role' => 'coach', 'is_coach' => true, 'company_code' => 'ABU15DN']);
        $student = User::factory()->create(['role' => 'user', 'company_code' => 'ABU15DN']);
        $other = User::factory()->create(['role' => 'user', 'company_code' => 'OTHER']);

        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/abundance')->assertOk()
            ->assertJsonPath('companyCode', 'ABU15DN')
            ->assertJsonCount(2, 'coaches')
            ->assertJsonCount(1, 'students');

        $this->postJson('/api/admin/abundance/assignments', [
            'coach_id' => (string) $coachOne->id,
            'student_id' => (string) $student->id,
        ])->assertOk();

        $this->postJson('/api/admin/abundance/assignments', [
            'coach_id' => (string) $coachTwo->id,
            'student_id' => (string) $student->id,
        ])->assertOk();

        $this->assertDatabaseMissing('coach_mentees', [
            'coach_id' => (string) $coachOne->id,
            'mentee_id' => (string) $student->id,
        ]);
        $this->assertDatabaseHas('coach_mentees', [
            'coach_id' => (string) $coachTwo->id,
            'mentee_id' => (string) $student->id,
        ]);

        Sanctum::actingAs($coachTwo);
        $this->getJson('/api/coach/mentees')
            ->assertOk()
            ->assertJsonPath('mentees.0.menteeId', (string) $student->id);
        Sanctum::actingAs($coachOne);
        $this->getJson('/api/coach/mentees')
            ->assertOk()
            ->assertJsonCount(0, 'mentees');

        Sanctum::actingAs($admin);
        $this->deleteJson('/api/admin/abundance/assignments/'.$student->id)->assertOk();
        $this->assertDatabaseMissing('coach_mentees', ['mentee_id' => (string) $student->id]);

        $this->postJson('/api/admin/abundance/assignments', [
            'coach_id' => (string) $coachTwo->id,
            'student_id' => (string) $other->id,
        ])->assertForbidden();
    }

    public function test_global_admin_can_use_the_abundance_tool_but_coaches_cannot_assign(): void
    {
        $otherAdmin = User::factory()->create(['role' => 'admin', 'is_admin' => true, 'company_code' => 'OTHER']);
        $coach = User::factory()->create(['role' => 'coach', 'is_coach' => true, 'company_code' => 'ABU15DN']);
        $student = User::factory()->create(['company_code' => 'ABU15DN']);

        Sanctum::actingAs($otherAdmin);
        $this->getJson('/api/admin/abundance')->assertOk()
            ->assertJsonPath('companyCode', 'ABU15DN');

        Sanctum::actingAs($coach);
        $this->postJson('/api/admin/abundance/assignments', [
            'coach_id' => (string) $coach->id,
            'student_id' => (string) $student->id,
        ])->assertForbidden();

        $this->postJson('/api/coach/mentees/assign', [
            'mentee_id' => (string) $student->id,
            'team_name' => 'Blocked',
        ])->assertForbidden();
    }

    public function test_admin_goal_and_task_management_preserves_existing_abundance_data(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'is_admin' => true, 'company_code' => 'ABU15DN']);
        $student = User::factory()->create(['company_code' => 'ABU15DN']);
        $goal = Goal::create([
            'id' => (string) Str::uuid(),
            'user_id' => $student->id,
            'category' => 'PERSONAL',
            'title' => 'Original goal',
            'status' => 'IN_PROGRESS',
            'goal_type' => 'MERIT',
            'direction' => 'GAIN',
            'target_value' => 10,
            'current_value' => 0,
            'target_period' => 'NONE',
            'start_date' => '2026-01-01',
            'target_date' => '2026-12-31',
            'progress' => 0,
        ]);

        Sanctum::actingAs($admin);
        $this->patchJson('/api/admin/abundance/goals/'.$goal->id, [
            'title' => 'Admin-edited goal',
            'current_value' => 5,
        ])->assertOk()->assertJsonPath('goal.title', 'Admin-edited goal');

        $task = $this->postJson('/api/admin/abundance/goals/'.$goal->id.'/tasks', [
            'title' => 'Admin quest',
        ])->assertCreated()->json('task');

        $this->assertDatabaseHas('goal_tasks', ['id' => $task['id'], 'title' => 'Admin quest']);
        $this->assertDatabaseHas('goals', ['id' => $goal->id, 'user_id' => $student->id, 'progress' => 50]);
    }
}
