<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class FoodMemory extends Model
{
    protected $table = 'food_memories';

    protected $fillable = [
        'user_id',
        'key',
        'display_name',
        'lookup_name',
        'calories',
        'protein',
        'carbs',
        'fat',
        'serving_quantity',
        'serving_unit',
        'grams_per_serving',
        'source',
        'use_count',
        'last_used_at',
    ];

    protected function casts(): array
    {
        return [
            'calories' => 'integer',
            'protein' => 'integer',
            'carbs' => 'integer',
            'fat' => 'integer',
            'serving_quantity' => 'float',
            'grams_per_serving' => 'float',
            'use_count' => 'integer',
            'last_used_at' => 'datetime',
        ];
    }
}
