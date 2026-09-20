<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AbundanceA12SessionTest extends TestCase
{
    use RefreshDatabase;

    public function test_abundance_admin_exchange_sends_only_the_server_validated_admin_intent(): void
    {
        config()->set('services.abundance_a12.url', 'https://a12.example.test/api/v1');
        config()->set('services.abundance_a12.secret', '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ');
        Http::fake(['https://a12.example.test/api/v1/auth/inneru-exchange' => Http::response([
            'accessToken' => 'a12-admin-token',
            'accessTokenExpiresAt' => now()->addMinutes(15)->toISOString(),
        ])]);
        $admin = User::factory()->create([
            'role' => 'admin',
            'is_admin' => true,
            'company_code' => 'ABU15DN',
            'email_verified_at' => now(),
        ]);

        Sanctum::actingAs($admin);

        $this->postJson('/api/abundance/a12/session')
            ->assertOk()
            ->assertJsonPath('accessToken', 'a12-admin-token');

    Http::assertSent(fn (HttpRequest $request): bool => $request->url() === 'https://a12.example.test/api/v1/auth/inneru-exchange'
            && $request['role'] === 'ADMIN'
            && $request['companyCode'] === 'ABU15DN');
    }

    public function test_global_admin_can_exchange_for_abundance_admin_management(): void
    {
        config()->set('services.abundance_a12.url', 'https://a12.example.test/api/v1');
        config()->set('services.abundance_a12.secret', '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ');
        Http::fake(['https://a12.example.test/api/v1/auth/inneru-exchange' => Http::response([
            'accessToken' => 'a12-global-admin-token',
            'accessTokenExpiresAt' => now()->addMinutes(15)->toISOString(),
        ])]);
        $admin = User::factory()->create([
            'role' => 'admin',
            'is_admin' => true,
            'company_code' => 'OTHER01',
            'email_verified_at' => now(),
        ]);

        Sanctum::actingAs($admin);

        $this->postJson('/api/abundance/a12/session')
            ->assertOk()
            ->assertJsonPath('accessToken', 'a12-global-admin-token');

        Http::assertSent(fn (HttpRequest $request): bool => $request->url() === 'https://a12.example.test/api/v1/auth/inneru-exchange'
            && $request['role'] === 'ADMIN'
            && $request['companyCode'] === 'ABU15DN');
    }
}
