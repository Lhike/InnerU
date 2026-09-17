<?php

namespace Tests\Feature;

use App\Models\CoachGroup;
use App\Models\CoachMentee;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AbundanceCouncilFallbackTest extends TestCase
{
    use RefreshDatabase;

    public function test_councils_reads_company_scoped_coach_groups(): void
    {
        $coach = User::factory()->create([
            'name' => 'Arlene Mae',
            'company_code' => 'ABU15DN',
            'company_name' => 'Abundance 12',
            'is_coach' => true,
            'role' => 'coach',
        ]);
        $member = User::factory()->create([
            'name' => 'Mentee One',
            'company_code' => 'ABU15DN',
            'company_name' => 'Abundance 12',
            'score' => 35,
        ]);
        $group = CoachGroup::create([
            'id' => 'dawn',
            'coach_id' => (string) $coach->id,
            'name' => 'Dawn',
            'company_code' => 'ABU15DN',
            'company_name' => 'Abundance 12',
        ]);
        CoachMentee::create([
            'coach_id' => (string) $coach->id,
            'mentee_id' => (string) $member->id,
            'mentee_name' => $member->name,
            'mentee_email' => $member->email,
            'group_id' => $group->id,
            'group_name' => $group->name,
        ]);

        $user = User::factory()->create([
            'company_code' => 'ABU15DN',
            'company_name' => 'Abundance 12',
        ]);
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/abundance/councils');

        $response->assertOk()
            ->assertJsonPath('councils.0.id', 'dawn')
            ->assertJsonPath('councils.0.name', 'Dawn')
            ->assertJsonPath('councils.0.coachName', 'Arlene Mae')
            ->assertJsonPath('councils.0.memberCount', 1)
            ->assertJsonPath('councils.0.averageScore', 35)
            ->assertJsonPath('councils.0.isCurrent', false);
    }

    public function test_join_and_leave_update_the_coach_group_membership(): void
    {
        $coach = User::factory()->create([
            'company_code' => 'ABU15DN',
            'company_name' => 'Abundance 12',
            'is_coach' => true,
            'role' => 'coach',
        ]);
        $user = User::factory()->create([
            'company_code' => 'ABU15DN',
            'company_name' => 'Abundance 12',
        ]);
        CoachGroup::create([
            'id' => 'dawn',
            'coach_id' => (string) $coach->id,
            'name' => 'Dawn',
            'company_code' => 'ABU15DN',
            'company_name' => 'Abundance 12',
        ]);
        Sanctum::actingAs($user);

        $this->postJson('/api/abundance/guild/join', ['councilId' => 'dawn'])
            ->assertOk()
            ->assertJsonPath('ok', true);
        $this->assertDatabaseHas('coach_mentees', [
            'coach_id' => (string) $coach->id,
            'mentee_id' => (string) $user->id,
            'group_id' => 'dawn',
        ]);

        $this->getJson('/api/abundance/guild')
            ->assertOk()
            ->assertJsonPath('councils.0.id', 'dawn');

        $this->postJson('/api/abundance/guild/leave')
            ->assertOk();
        $this->assertDatabaseHas('coach_mentees', [
            'coach_id' => (string) $coach->id,
            'mentee_id' => (string) $user->id,
            'group_id' => null,
        ]);
    }
}
