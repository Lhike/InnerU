<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\DailyTracker;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class StepLeaderboardTest extends TestCase
{
    use RefreshDatabase;

    private function makeCompany(string $name, string $code): Company
    {
        return Company::create([
            'id' => (string) Str::uuid(),
            'name' => $name,
            'code' => $code,
        ]);
    }

    private function makeMember(Company $company, string $name): User
    {
        return User::factory()->create([
            'name' => $name,
            'company_id' => $company->id,
            'company_code' => $company->code,
            'company_name' => $company->name,
        ]);
    }

    private function logSteps(User $user, string $date, int $steps): void
    {
        DailyTracker::create([
            'user_id' => (string) $user->id,
            'username' => $user->name,
            'date' => $date,
            'step_count' => $steps,
        ]);
    }

    public function test_it_ranks_company_members_by_total_steps_for_the_period(): void
    {
        $company = $this->makeCompany('Acme', 'ACME1');
        $other = $this->makeCompany('Other', 'OTHER');

        $ana = $this->makeMember($company, 'Ana');
        $ben = $this->makeMember($company, 'Ben');
        $cara = $this->makeMember($company, 'Cara');
        $outsider = $this->makeMember($other, 'Outsider');

        // Week of Mon 2026-10-19 .. Sun 2026-10-25.
        $this->logSteps($ana, '2026-10-19', 4000);
        $this->logSteps($ana, '2026-10-20', 3000);
        $this->logSteps($ben, '2026-10-20', 9000);
        $this->logSteps($ben, '2026-10-12', 50000); // previous week
        $this->logSteps($outsider, '2026-10-20', 99999);

        Sanctum::actingAs($ana);

        $response = $this->getJson('/api/leaderboard/steps?period=week&date=2026-10-21');

        $response->assertOk()
            ->assertJsonPath('period', 'week')
            ->assertJsonPath('startDate', '2026-10-19')
            ->assertJsonPath('endDate', '2026-10-25')
            ->assertJsonPath('company.code', 'ACME1')
            ->assertJsonPath('companyTotalSteps', 16000);

        $entries = collect($response->json('entries'));
        $this->assertSame(['Ben', 'Ana', 'Cara'], $entries->pluck('name')->all());
        $this->assertSame([9000, 7000, 0], $entries->pluck('totalSteps')->all());
        $this->assertSame([1, 2, 3], $entries->pluck('rank')->all());
        $this->assertFalse($entries->pluck('userId')->contains((string) $outsider->id));
    }

    public function test_it_reports_the_viewers_daily_race_placements_for_the_week(): void
    {
        $company = $this->makeCompany('Acme', 'ACME1');
        $ana = $this->makeMember($company, 'Ana');
        $ben = $this->makeMember($company, 'Ben');

        $this->logSteps($ana, '2026-10-19', 4000); // Mon: Ana 1st
        $this->logSteps($ben, '2026-10-19', 3000);
        $this->logSteps($ana, '2026-10-20', 1000); // Tue: Ana 2nd
        $this->logSteps($ben, '2026-10-20', 9000);
        $this->logSteps($ben, '2026-10-21', 500);  // Wed: Ana didn't walk

        Sanctum::actingAs($ana);

        $placements = $this->getJson('/api/leaderboard/steps?period=today&date=2026-10-21')
            ->assertOk()
            ->json('weekPlacements');

        $this->assertCount(7, $placements);
        $this->assertSame(['date' => '2026-10-19', 'steps' => 4000, 'rank' => 1], $placements[0]);
        $this->assertSame(['date' => '2026-10-20', 'steps' => 1000, 'rank' => 2], $placements[1]);
        $this->assertSame(['date' => '2026-10-21', 'steps' => 0, 'rank' => null], $placements[2]);
        $this->assertSame('2026-10-25', $placements[6]['date']);
    }

    public function test_today_and_all_time_periods(): void
    {
        $company = $this->makeCompany('Acme', 'ACME1');
        $ana = $this->makeMember($company, 'Ana');
        $ben = $this->makeMember($company, 'Ben');

        $this->logSteps($ana, '2026-10-19', 1000);
        $this->logSteps($ben, '2026-10-01', 20000);

        Sanctum::actingAs($ana);

        $today = $this->getJson('/api/leaderboard/steps?period=today&date=2026-10-19');
        $today->assertOk()->assertJsonPath('entries.0.name', 'Ana');

        $all = $this->getJson('/api/leaderboard/steps?period=all');
        $all->assertOk()
            ->assertJsonPath('startDate', null)
            ->assertJsonPath('entries.0.name', 'Ben')
            ->assertJsonPath('companyTotalSteps', 21000);
    }

    public function test_it_rejects_unknown_periods(): void
    {
        $company = $this->makeCompany('Acme', 'ACME1');
        Sanctum::actingAs($this->makeMember($company, 'Ana'));

        $this->getJson('/api/leaderboard/steps?period=year')->assertStatus(422);
    }
}
