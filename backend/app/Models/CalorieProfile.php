<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CalorieProfile extends Model
{
    protected $table = 'calorie_profiles';

    protected $fillable = [
        'user_id',
        'sex',
        'age',
        'height_cm',
        'weight_kg',
        'activity_level',
        'goal_type',
        'count_steps',
        'daily_goal',
    ];

    protected function casts(): array
    {
        return [
            'age' => 'integer',
            'height_cm' => 'float',
            'weight_kg' => 'float',
            'count_steps' => 'boolean',
            'daily_goal' => 'integer',
        ];
    }
}
