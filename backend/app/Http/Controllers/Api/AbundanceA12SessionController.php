<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/** Exchanges an authenticated InnerU account for a short-lived A12 session. */
class AbundanceA12SessionController extends Controller
{
    public function __invoke(Request $request): JsonResponse
    {
        $user = $request->user();
        $code = strtoupper(trim((string) ($user->active_company_code ?? $user->company_code ?? '')));
        $isAdmin = (bool) ($user->is_admin ?? false)
            || strtolower(trim((string) ($user->role ?? ''))) === 'admin';
        if ($code !== 'ABU15DN' && ! $isAdmin) {
            return response()->json(['message' => 'Abundance access is not enabled for this account.'], Response::HTTP_FORBIDDEN);
        }
        $url = rtrim((string) config('services.abundance_a12.url'), '/');
        $secret = (string) config('services.abundance_a12.secret');
        if ($url === '' || $secret === '') {
            return response()->json(['message' => 'Abundance data service is not configured.'], Response::HTTP_SERVICE_UNAVAILABLE);
        }
        $payload = [
            'inneruUserId' => (string) $user->id,
            'email' => strtolower(trim((string) $user->email)),
            'name' => (string) $user->name,
            // A12 owns Abundance roles. InnerU can only attest its existing
            // administrator authorization for the A12 admin console; it must
            // not promote a local Coach flag into an A12 Coach role.
            'role' => ((bool) ($user->is_admin ?? false) || strtolower(trim((string) ($user->role ?? ''))) === 'admin')
                ? 'ADMIN'
                : 'MEMBER',
            'companyCode' => 'ABU15DN',
            'emailVerified' => $user->email_verified_at !== null,
        ];
        $body = json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        $timestamp = (string) now()->timestamp;
        $nonce = (string) Str::uuid();
        $signature = hash_hmac('sha256', "POST\n/api/v1/auth/inneru-exchange\n{$timestamp}\n{$nonce}\n{$body}", $secret);
        $response = Http::acceptJson()->asJson()
            ->connectTimeout((int) config('services.abundance_a12.connect_timeout', 3))
            ->timeout((int) config('services.abundance_a12.timeout', 8))
            ->withHeaders(['X-InnerU-Timestamp' => $timestamp, 'X-InnerU-Nonce' => $nonce, 'X-InnerU-Signature' => $signature])
            ->post($url.'/auth/inneru-exchange', $payload);
        if (! $response->successful()) {
            return response()->json(['message' => 'Abundance data service is unavailable.'], Response::HTTP_BAD_GATEWAY);
        }
        $data = $response->json();
        if (! is_array($data) || ! is_string($data['accessToken'] ?? null) || $data['accessToken'] === '') {
            return response()->json(['message' => 'Abundance data service returned an invalid session.'], Response::HTTP_BAD_GATEWAY);
        }
        return response()->json($data);
    }
}
