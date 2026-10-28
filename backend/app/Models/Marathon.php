<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

class Marathon extends Model
{
    /** Theme keys the app knows how to draw. 'custom' carries its own theme_data. */
    public const THEMES = ['sunrise', 'ocean', 'forest', 'sakura', 'neon_night', 'holiday', 'independence', 'undersea', 'custom'];

    /** Walker accessories and tops a custom kit may use (see the app's walker). */
    public const KIT_ACCESSORIES = ['none', 'backpack', 'cap', 'headphones', 'crown'];

    public const KIT_TOPS = ['tee', 'hoodie', 'tank'];

    protected $fillable = [
        'title',
        'description',
        'theme',
        'theme_data',
        'kit_image_url',
        'distance_km',
        'price',
        'currency',
        'starts_at',
        'ends_at',
        'registration_opens_at',
        'registration_closes_at',
        'payment_instructions',
        'payment_qr_url',
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
            'registration_opens_at' => 'date:Y-m-d',
            'registration_closes_at' => 'date:Y-m-d',
            'theme_data' => 'array',
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

    /** Last day people can join: the set closing date, else the race's end. */
    public function registrationClosesOn(): Carbon
    {
        return ($this->registration_closes_at ?? $this->ends_at)->copy();
    }

    /** not_yet, open or closed, for [$today] in the app's time zone. */
    public function registrationStatus(?Carbon $today = null): string
    {
        $today = ($today ?? now())->copy()->startOfDay();
        if ($this->registration_opens_at !== null && $today->lt($this->registration_opens_at)) {
            return 'not_yet';
        }

        return $today->gt($this->registrationClosesOn()) ? 'closed' : 'open';
    }
}
