<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\PendingRegistration;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Tests\TestCase;

class AbundanceRegistrationProvisioningTest extends TestCase
{
    use RefreshDatabase;

    public function test_verifying_an_abundance_registration_provisions_the_a12_user(): void
    {
        $company = Company::create([
            'id' => (string) Str::uuid(),
            'name' => 'Abundance 12',
            'code' => 'ABU15DN',
            'is_active' => true,
        ]);

        config()->set('services.a12.url', 'https://a14-api.valenin.com');
        config()->set('services.a12.bridge_secret', 'test-bridge-secret');
        Http::fake([
            'https://a14-api.valenin.com/api/v1/auth/inneru-exchange' => Http::response([
                'provisioned' => true,
                'mobileUserId' => 'a12-user-1',
            ]),
        ]);

        $pending = PendingRegistration::create([
            'name' => 'Ari Member',
            'email' => 'ari@example.test',
            'encrypted_password' => Crypt::encryptString('password-123'),
            'role' => 'user',
            'company_code' => $company->code,
            'company_name' => $company->name,
            'has_company' => true,
            'company_id' => $company->id,
            'active_company_id' => $company->id,
            'active_company_code' => $company->code,
            'active_company_name' => $company->name,
        ]);

        $this->get($pending->verificationUrl())
            ->assertOk()
            ->assertViewIs('auth.email-verified');

        $this->assertDatabaseHas('users', [
            'email' => 'ari@example.test',
            'active_company_code' => 'ABU15DN',
        ]);

        Http::assertSent(function ($request): bool {
            return $request->url() === 'https://a14-api.valenin.com/api/v1/auth/inneru-exchange'
                && $request['companyCode'] === 'ABU15DN'
                && $request['emailVerified'] === true
                && $request['provisionOnly'] === true;
        });
    }

    public function test_verifying_a_non_abundance_registration_does_not_call_a12(): void
    {
        config()->set('services.a12.url', 'https://a14-api.valenin.com');
        config()->set('services.a12.bridge_secret', 'test-bridge-secret');
        Http::fake();

        $pending = PendingRegistration::create([
            'name' => 'Standard Member',
            'email' => 'standard@example.test',
            'encrypted_password' => Crypt::encryptString('password-123'),
            'role' => 'user',
            'company_code' => 'STANDARD',
            'company_name' => 'Standard',
            'has_company' => true,
            'active_company_code' => 'STANDARD',
            'active_company_name' => 'Standard',
        ]);

        $this->get($pending->verificationUrl())->assertOk();

        Http::assertNothingSent();
    }
}
