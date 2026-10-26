<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class A12BridgeClient
{
    /** Provision an InnerU Abundance member in the A12 user table. */
    public function provisionAbundanceUser(User $user): array
    {
        $companyCode = strtoupper(trim((string) ($user->active_company_code ?: $user->company_code)));

        if ($companyCode !== 'ABU15DN' || $user->email_verified_at === null) {
            return [];
        }

        return $this->exchange([
            'inneruUserId' => (string) $user->id,
            'email' => (string) $user->email,
            'name' => (string) $user->name,
            'role' => $user->is_coach ? 'COACH' : 'MEMBER',
            'companyCode' => $companyCode,
            'emailVerified' => true,
            'provisionOnly' => true,
        ]);
    }

    /** @return array<string, mixed> */
    public function exchange(array $identity): array
    {
        $url = rtrim((string) config('services.a12.url'), '/');
        $secret = (string) config('services.a12.bridge_secret');
        if ($url === '' || $secret === '') {
            throw new \LogicException('Abundance data service is not configured.');
        }

        $path = '/api/v1/auth/inneru-exchange';
        $timestamp = (string) now()->timestamp;
        $nonce = (string) Str::uuid();
        $body = json_encode($identity, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
        $signature = hash_hmac(
            'sha256',
            "POST\n{$path}\n{$timestamp}\n{$nonce}\n{$body}",
            $secret,
        );

        $response = Http::acceptJson()
            ->connectTimeout((int) config('services.a12.connect_timeout', 5))
            ->timeout((int) config('services.a12.timeout', 15))
            ->withHeaders([
                'Content-Type' => 'application/json',
                'X-InnerU-Timestamp' => $timestamp,
                'X-InnerU-Nonce' => $nonce,
                'X-InnerU-Signature' => $signature,
            ])
            ->withBody($body, 'application/json')
            ->post($url.$path);

        $response->throw();

        return $response->json();
    }
}
