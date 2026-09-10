<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\UserScoreService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AnalyticsEmployeeScoreController extends Controller
{
    public function __construct(private readonly UserScoreService $userScoreService) {}

    public function index(Request $request): JsonResponse
    {
        $admin = $request->user();
        $role = strtolower(trim((string) ($admin?->role ?? '')));
        if ($admin === null || ($role !== 'admin' && ! (bool) $admin->is_admin)) {
            return response()->json(['message' => 'Forbidden.'], Response::HTTP_FORBIDDEN);
        }

        $companyCodes = collect(explode(',', (string) $request->query('companyCodes', '')))
            ->map(static fn (string $code): string => strtoupper(trim($code)))
            ->filter()
            ->unique()
            ->values();

        if ($companyCodes->isEmpty()) {
            return response()->json(['message' => 'At least one company code is required.'], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        $placeholders = implode(',', array_fill(0, $companyCodes->count(), '?'));
        $users = User::query()
            ->whereRaw("upper(trim(coalesce(nullif(active_company_code, ''), nullif(company_code, '')))) in ({$placeholders})", $companyCodes->all())
            ->orderBy('id')
            ->get();
        $breakdowns = $this->userScoreService->resolveBreakdownForUsers($users);

        $scores = $users->map(function (User $user) use ($breakdowns): array {
            $id = (string) $user->id;

            return [
                'userId' => $id,
                'overallScore' => (float) ($breakdowns[$id]['overallScore'] ?? 0),
            ];
        })->values();

        return response()->json(['scores' => $scores]);
    }
}
