<?php

namespace App\Services;

use App\Models\Marathon;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Turns an admin's idea ("under the sea", "superheroes") into a marathon
 * theme: colours and a walker kit the app draws, plus an optional picture
 * of the kit. Uses OpenAI.
 */
class MarathonThemeGenerator
{
    private const SYSTEM_PROMPT = <<<'TXT'
You design themes for a virtual walking and running marathon in a wellness app.
Given the admin's idea, reply with a JSON object only:
{
  "name": short theme name, at most 3 words,
  "emoji": one emoji,
  "tagline": one upbeat sentence describing the marathon,
  "gradient": [two hex colours for the race background, lighter first],
  "kitTop": hex colour of the runner's shirt,
  "kitBottom": hex colour of the shorts,
  "kitShoes": hex colour of the shoes,
  "top": one of "tee", "hoodie", "tank",
  "accessory": one of "none", "backpack", "cap", "headphones", "crown"
}
Pick colours that clearly evoke the idea.
If the idea names a copyrighted or trademarked character, show or brand,
capture its colours and mood but give the theme an original name that does
not use the character or brand name.
TXT;

    public function configured(): bool
    {
        return filled(config('services.openai.key'));
    }

    /** Theme data for a 'custom' marathon, ready to store in theme_data. */
    public function theme(string $idea): array
    {
        $response = $this->client(timeout: 45)->post('chat/completions', [
            'model' => config('services.openai.model'),
            'response_format' => ['type' => 'json_object'],
            'messages' => [
                ['role' => 'system', 'content' => self::SYSTEM_PROMPT],
                ['role' => 'user', 'content' => $idea],
            ],
        ])->throw();

        $content = json_decode((string) $response->json('choices.0.message.content'), true);

        return self::sanitize(is_array($content) ? $content : [], $idea);
    }

    /** Draws the kit for [$theme] and returns the stored picture's URL. */
    public function kitImage(array $theme, string $idea): string
    {
        $top = ['tee' => 'T-shirt', 'hoodie' => 'hoodie', 'tank' => 'tank top'][$theme['top'] ?? 'tee'] ?? 'T-shirt';
        $prompt = "Flat vector illustration of a virtual marathon runner's kit laid out neatly: "
            ."a {$top} in {$theme['kitTop']} with a blank race bib, shorts in {$theme['kitBottom']}, "
            ."running shoes in {$theme['kitShoes']} and a finisher medal, on a background blending "
            ."{$theme['gradient'][0]} and {$theme['gradient'][1]}. "
            ."Theme: \"{$theme['name']}\", inspired by: {$idea}. Playful and colourful. "
            .'No words, no logos, no real people and no copyrighted characters.';

        $response = $this->client(timeout: 150)->post('images/generations', [
            'model' => config('services.openai.image_model'),
            'prompt' => $prompt,
            'size' => '1024x1024',
            'n' => 1,
        ])->throw();

        $image = $response->json('data.0') ?? [];
        $bytes = match (true) {
            isset($image['b64_json']) => base64_decode((string) $image['b64_json'], true),
            isset($image['url']) => Http::timeout(60)->get($image['url'])->throw()->body(),
            default => false,
        };
        if (! is_string($bytes) || $bytes === '') {
            throw new RuntimeException('OpenAI returned no image.');
        }

        $disk = (string) config('filesystems.media_upload_disk', 'public');
        $prefix = trim((string) config('filesystems.media_upload_path', ''), '/');
        $path = ltrim("{$prefix}/marathons/kits/".Str::uuid().'.png', '/');
        Storage::disk($disk)->put($path, $bytes, ['visibility' => 'public']);

        return Storage::disk($disk)->url($path);
    }

    /** Keeps only well-formed values so the app can always draw the theme. */
    public static function sanitize(array $raw, string $idea): array
    {
        $hex = function (mixed $value, string $fallback): string {
            $value = ltrim(trim((string) (is_string($value) ? $value : '')), '#');
            if (preg_match('/\A[0-9a-fA-F]{3}\z/', $value)) {
                $value = preg_replace('/(.)/', '$1$1', $value);
            }

            return preg_match('/\A[0-9a-fA-F]{6}\z/', $value) ? '#'.strtoupper($value) : $fallback;
        };
        $gradient = is_array($raw['gradient'] ?? null) ? array_values($raw['gradient']) : [];
        $text = fn (mixed $value, int $max): string => Str::limit(trim(is_string($value) ? $value : ''), $max, '');

        return [
            'name' => $text($raw['name'] ?? '', 40) ?: Str::title(Str::limit($idea, 40, '')),
            'emoji' => $text($raw['emoji'] ?? '', 16) ?: '🏃',
            'tagline' => $text($raw['tagline'] ?? '', 300),
            'gradient' => [$hex($gradient[0] ?? null, '#FF9A44'), $hex($gradient[1] ?? null, '#FC6076')],
            'kitTop' => $hex($raw['kitTop'] ?? null, '#FF7043'),
            'kitBottom' => $hex($raw['kitBottom'] ?? null, '#37474F'),
            'kitShoes' => $hex($raw['kitShoes'] ?? null, '#FFC93C'),
            'top' => in_array($raw['top'] ?? null, Marathon::KIT_TOPS, true) ? $raw['top'] : 'tee',
            'accessory' => in_array($raw['accessory'] ?? null, Marathon::KIT_ACCESSORIES, true) ? $raw['accessory'] : 'none',
            'prompt' => $text($idea, 200),
        ];
    }

    private function client(int $timeout): PendingRequest
    {
        return Http::baseUrl(rtrim((string) config('services.openai.base_url'), '/'))
            ->withToken((string) config('services.openai.key'))
            ->acceptJson()
            ->timeout($timeout);
    }
}
