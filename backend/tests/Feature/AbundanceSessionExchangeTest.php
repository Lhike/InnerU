<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Company;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AbundanceSessionExchangeTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_verified_abundance_members_can_exchange_for_an_a12_session(): void
    {
        Http::fake([
            'https://a14-api.valenin.com/api/v1/auth/inneru-exchange' => Http::response([
                'accessToken' => 'a12-access-token',
                'refreshToken' => null,
                'accessTokenExpiresAt' => now()->addMinutes(15)->toISOString(),
            ]),
        ]);
        config()->set('services.a12.url', 'https://a14-api.valenin.com');
        config()->set('services.a12.bridge_secret', 'test-bridge-secret');

        $otherCompany = User::factory()->create(['active_company_code' => 'OTHER']);
        Sanctum::actingAs($otherCompany);
        $this->postJson('/api/abundance/session')->assertForbidden();
        Http::assertNothingSent();

        $company = Company::create([
            'id' => (string) Str::uuid(), 'name' => 'Abundance', 'code' => 'ABU15DN', 'is_active' => true,
        ]);
        $member = User::factory()->create([
            'name' => 'Ari Member',
            'email' => 'ari@example.test',
            'active_company_code' => 'ABU15DN',
            'email_verified_at' => now(),
            'role' => 'user',
            'is_coach' => false,
            'company_id' => $company->id,
            'active_company_id' => $company->id,
        ]);
        Sanctum::actingAs($member);

        $this->postJson('/api/abundance/session')
            ->assertOk()
            ->assertJsonPath('accessToken', 'a12-access-token');

        Http::assertSent(function ($request): bool {
            $timestamp = $request->header('X-InnerU-Timestamp')[0] ?? '';
            $nonce = $request->header('X-InnerU-Nonce')[0] ?? '';
            $signature = $request->header('X-InnerU-Signature')[0] ?? '';
            $expected = hash_hmac(
                'sha256',
                "POST\n/api/v1/auth/inneru-exchange\n{$timestamp}\n{$nonce}\n{$request->body()}",
                'test-bridge-secret',
            );

            return $request->url() === 'https://a14-api.valenin.com/api/v1/auth/inneru-exchange'
                && hash_equals($expected, $signature)
                && $request['inneruUserId'] === (string) auth()->id()
                && $request['companyCode'] === 'ABU15DN'
                && $request['emailVerified'] === true;
        });
    }

    public function test_exchange_returns_service_unavailable_when_a12_is_not_configured(): void
    {
        $company = Company::create([
            'id' => (string) Str::uuid(), 'name' => 'Abundance', 'code' => 'ABU15DN', 'is_active' => true,
        ]);
        config()->set('services.a12.url', null);
        config()->set('services.a12.bridge_secret', null);
        Sanctum::actingAs(User::factory()->create([
            'active_company_code' => 'ABU15DN',
            'company_id' => $company->id,
            'active_company_id' => $company->id,
            'email_verified_at' => now(),
        ]));

        $this->postJson('/api/abundance/session')
            ->assertStatus(503)
            ->assertJsonPath('message', 'Abundance data service is not configured.');
    }
}
