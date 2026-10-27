<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MarathonRegistration;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;
use Symfony\Component\HttpFoundation\Response;

/**
 * Saves the user's steps-race walker so other members of their company
 * see it in the race.
 */
class WalkerLookController extends Controller
{
    public const HAIR_STYLES = ['short', 'long', 'ponytail', 'bun', 'curly', 'buzz'];

    public const TOPS = ['tee', 'hoodie', 'tank'];

    public const BOTTOMS = ['pants', 'shorts'];

    public const ACCESSORIES = ['none', 'backpack', 'cap', 'headphones', 'crown'];

    private const COLOR_KEYS = ['skin', 'hair', 'topColor', 'bottomColor', 'shoes'];

    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        return response()->json(['look' => $user->walker_look]);
    }

    public function update(Request $request): JsonResponse
    {
        $user = $request->user();
        if ($user === null) {
            return response()->json(['message' => 'Unauthorized.'], Response::HTTP_UNAUTHORIZED);
        }

        $colorRule = ['required', 'integer', 'min:0', 'max:4294967295'];
        $validated = $request->validate([
            'look' => ['required', 'array'],
            'look.hairStyle' => ['required', Rule::in(self::HAIR_STYLES)],
            'look.top' => ['required', Rule::in(self::TOPS)],
            'look.bottom' => ['required', Rule::in(self::BOTTOMS)],
            'look.accessory' => ['required', Rule::in(self::ACCESSORIES)],
            ...collect(self::COLOR_KEYS)
                ->mapWithKeys(fn (string $key) => ["look.$key" => $colorRule])
                ->all(),
            // A marathon kit: the theme's outfit with the runner's bib.
            'look.kit' => ['nullable', 'string', 'max:40', 'required_with:look.bib'],
            'look.bib' => ['nullable', 'integer', 'min:1', 'required_with:look.kit'],
        ]);

        $kit = $validated['look']['kit'] ?? null;
        if ($kit !== null && ! $this->ownsKit($user->id, $kit, (int) $validated['look']['bib'])) {
            return response()->json([
                'message' => 'You can wear a marathon kit once your registration is confirmed.',
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        // Keep only known keys so the column can't be used to store
        // arbitrary data.
        $look = collect($validated['look'])
            ->only([...self::COLOR_KEYS, 'hairStyle', 'top', 'bottom', 'accessory', 'kit', 'bib'])
            ->filter(fn ($value) => $value !== null)
            ->map(fn ($value, string $key) => in_array($key, [...self::COLOR_KEYS, 'bib'], true) ? (int) $value : $value)
            ->all();

        $user->forceFill(['walker_look' => $look])->save();

        return response()->json(['look' => $user->walker_look]);
    }

    /** Whether the user is a confirmed runner in a [$theme] marathon with that bib. */
    private function ownsKit(int|string $userId, string $theme, int $bib): bool
    {
        return MarathonRegistration::query()
            ->where('user_id', $userId)
            ->where('status', 'confirmed')
            ->where('bib_number', $bib)
            ->whereHas('marathon', fn ($q) => $q->where('theme', $theme))
            ->exists();
    }
}
