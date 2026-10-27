<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

class Marathon extends Model
{
    /** Theme keys the app knows how to draw. */
    public const THEMES = ['sunrise', 'ocean', 'forest', 'sakura', 'neon_night', 'holiday', 'independence'];

    protected $fillable = [
        'title',
        'description',
        'theme',
        'distance_km',
        'price',
        'currency',
        'starts_at',
        'ends_at',
        'payment_instructions',
        'is_published',
        'created_by',
    ];

    protected function casts(): array
    {
        return [
            'distance_km' => 'float',
            'price' => 'float',
            'starts_at' => 'date:Y-m-d',
            'ends_at' => 'date:Y-m-d',
            'is_published' => 'boolean',
        ];
    }

    public function registrations(): HasMany
    {
        return $this->hasMany(MarathonRegistration::class);
    }

    /** upcoming, ongoing or ended, for [$today] in the app's time zone. */
    public function phase(?Carbon $today = null): string
    {
        $today = ($today ?? now())->copy()->startOfDay();
        if ($today->lt($this->starts_at)) {
            return 'upcoming';
        }

        return $today->gt($this->ends_at) ? 'ended' : 'ongoing';
    }
}
