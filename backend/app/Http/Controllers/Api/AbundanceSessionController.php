<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\A12BridgeClient;
use App\Models\Company;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AbundanceSessionController extends Controller
{
    public function __invoke(Request $request, A12BridgeClient $bridge): JsonResponse
    {
        $user = $request->user();
        $companyId = trim((string) ($user->active_company_id ?: $user->company_id));
        $company = $companyId === '' ? null : Company::query()
            ->whereKey($companyId)
            ->where('is_active', true)
            ->first();
        if ($company === null || strtoupper(trim((string) $company->code)) !== 'ABU15DN') {
            return response()->json(
                ['message' => 'The Abundance data service is available only to ABU15DN members.'],
                Response::HTTP_FORBIDDEN,
            );
        }
        if ($user->email_verified_at === null) {
            return response()->json(
                ['message' => 'Verify your email before entering Abundance.'],
                Response::HTTP_FORBIDDEN,
            );
        }

        try {
            return response()->json($bridge->exchange([
                'inneruUserId' => (string) $user->id,
                'email' => (string) $user->email,
                'name' => (string) $user->name,
                'role' => $user->is_coach ? 'COACH' : 'MEMBER',
                'companyCode' => strtoupper(trim((string) $company->code)),
                'emailVerified' => true,
            ]));
        } catch (\LogicException $exception) {
            return response()->json(
                ['message' => $exception->getMessage()],
                Response::HTTP_SERVICE_UNAVAILABLE,
            );
        } catch (ConnectionException|RequestException $exception) {
            report($exception);

            return response()->json(
                ['message' => 'The Abundance data service is temporarily unavailable.'],
                Response::HTTP_BAD_GATEWAY,
            );
        }
    }
}
