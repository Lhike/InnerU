<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\UserScoreService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Mockery;
use Tests\TestCase;

class AnalyticsEmployeeScoreApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_an_admin_receives_decimal_official_scores_for_requested_companies(): void
    {
        $admin = User::factory()->create(['role' => 'admin', 'is_admin' => true]);
        $included = User::factory()->create(['company_code' => 'GENCYS', 'active_company_code' => 'GENCYS']);
        User::factory()->create(['company_code' => 'OTHER', 'active_company_code' => 'OTHER']);

        $service = Mockery::mock(UserScoreService::class);
        $service->shouldReceive('resolveBreakdownForUsers')->once()->andReturn([
            (string) $included->id => ['goalScore' => 0.0, 'coreTaskScore' => 20.9, 'overallScore' => 20.9],
        ]);
        $this->app->instance(UserScoreService::class, $service);
        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/analytics/employee-scores?companyCodes=GENCYS')
            ->assertOk()
            ->assertExactJson(['scores' => [['userId' => (string) $included->id, 'overallScore' => 20.9]]]);
    }

    public function test_a_non_admin_cannot_read_analytics_scores(): void
    {
        Sanctum::actingAs(User::factory()->create(['role' => 'user', 'is_admin' => false]));

        $this->getJson('/api/admin/analytics/employee-scores?companyCodes=GENCYS')
            ->assertForbidden();
    }
}
