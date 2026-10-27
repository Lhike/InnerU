<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MarathonRegistration extends Model
{
    public const SHIRT_SIZES = ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL'];

    protected $fillable = [
        'marathon_id',
        'user_id',
        'full_name',
        'email',
        'phone',
        'shirt_size',
        'shipping_address',
        'status',
        'payment_reference',
        'payment_proof_url',
        'payment_submitted_at',
        'reviewed_by',
        'reviewed_at',
        'rejection_reason',
        'bib_number',
        'finished_at',
        'certificate_number',
        'rewards_shipped_at',
    ];

    protected function casts(): array
    {
        return [
            'payment_submitted_at' => 'datetime',
            'reviewed_at' => 'datetime',
            'finished_at' => 'datetime',
            'rewards_shipped_at' => 'datetime',
            'bib_number' => 'integer',
        ];
    }

    public function marathon(): BelongsTo
    {
        return $this->belongsTo(Marathon::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
