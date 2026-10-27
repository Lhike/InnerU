<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
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
        ]);

        // Keep only known keys so the column can't be used to store
        // arbitrary data.
        $look = collect($validated['look'])
            ->only([...self::COLOR_KEYS, 'hairStyle', 'top', 'bottom', 'accessory'])
            ->map(fn ($value, string $key) => in_array($key, self::COLOR_KEYS, true) ? (int) $value : $value)
            ->all();

        $user->forceFill(['walker_look' => $look])->save();

        return response()->json(['look' => $user->walker_look]);
    }
}
