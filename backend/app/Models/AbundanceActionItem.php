<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AbundanceActionItem extends Model
{
    protected $table = 'abundance_action_items';
    protected $fillable = ['id', 'coach_id', 'mentee_id', 'title', 'due_date', 'status', 'completed_at'];
    protected $casts = ['due_date' => 'date', 'completed_at' => 'datetime'];
}
