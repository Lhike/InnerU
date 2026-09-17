<?php

namespace App\Models;

use Illuminate\Support\Carbon;
use Illuminate\Database\Eloquent\Model;

class TodoTask extends Model
{
    protected $table = 'todo_tasks';

    protected $fillable = [
        'id',
        'user_id',
        'title',
        'description',
        'goal_type',
        'start_date',
        'due_date',
        'tag',
        'is_completed',
        'completed_at',
        'scheduled_time',
        'completion_dates',
        'sub_tasks',
    ];

    protected $casts = [
        'goal_type' => 'string',
        'start_date' => 'date',
        'due_date' => 'date',
        'is_completed' => 'boolean',
        'completed_at' => 'datetime',
        'completion_dates' => 'array',
        'sub_tasks' => 'array',
    ];

    /**
     * PostgreSQL returns TIME columns with seconds while SQLite commonly
     * returns the value exactly as submitted. Keep the API/model contract
     * stable across both databases for every InnerU company.
     */
    public function getScheduledTimeAttribute($value): ?string
    {
        return $value === null ? null : Carbon::parse($value)->format('H:i');
    }

    public $incrementing = false;

    protected $keyType = 'string';
}
