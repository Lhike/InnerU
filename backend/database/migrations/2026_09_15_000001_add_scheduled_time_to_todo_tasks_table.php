<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('todo_tasks', function (Blueprint $table): void {
            $table->time('scheduled_time')->nullable()->after('due_date');
        });
    }

    public function down(): void
    {
        Schema::table('todo_tasks', function (Blueprint $table): void {
            $table->dropColumn('scheduled_time');
        });
    }
};
