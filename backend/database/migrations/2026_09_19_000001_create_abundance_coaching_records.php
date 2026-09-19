<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('abundance_coaching_notes', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('coach_id');
            $table->string('mentee_id');
            $table->text('body');
            $table->timestamps();
            $table->index(['coach_id', 'mentee_id']);
        });
        Schema::create('abundance_action_items', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('coach_id');
            $table->string('mentee_id');
            $table->string('title');
            $table->date('due_date')->nullable();
            $table->string('status')->default('OPEN');
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();
            $table->index(['coach_id', 'mentee_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('abundance_action_items');
        Schema::dropIfExists('abundance_coaching_notes');
    }
};
