<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AbundanceCoachingNote extends Model
{
    protected $table = 'abundance_coaching_notes';
    protected $fillable = ['id', 'coach_id', 'mentee_id', 'body'];
}
