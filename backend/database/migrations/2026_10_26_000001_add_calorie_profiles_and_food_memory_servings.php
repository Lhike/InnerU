<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('calorie_profiles', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained('users')->cascadeOnDelete();
            $table->string('sex', 16)->nullable();
            $table->unsignedSmallInteger('age')->nullable();
            $table->decimal('height_cm', 5, 1)->nullable();
            $table->decimal('weight_kg', 5, 1)->nullable();
            $table->string('activity_level', 32)->default('sedentary');
            $table->string('goal_type', 32)->default('maintain');
            // When true the daily goal assumes a sedentary baseline and the
            // calories burned from steps are added back each day.
            $table->boolean('count_steps')->default(true);
            $table->unsignedInteger('daily_goal')->nullable();
            $table->timestamps();
        });

        Schema::table('food_memories', function (Blueprint $table): void {
            // The nutrition columns now describe one serving_quantity of
            // serving_unit (e.g. 1 serving, 100 g) instead of whatever total
            // happened to be logged.
            $table->decimal('serving_quantity', 8, 2)->nullable()->after('fat');
            $table->string('serving_unit', 50)->nullable()->after('serving_quantity');
            $table->decimal('grams_per_serving', 8, 2)->nullable()->after('serving_unit');
            $table->unsignedInteger('use_count')->default(0)->after('source');
            $table->timestamp('last_used_at')->nullable()->after('use_count');
            $table->index(['user_id', 'last_used_at']);
        });
    }

    public function down(): void
    {
        Schema::table('food_memories', function (Blueprint $table): void {
            $table->dropIndex(['user_id', 'last_used_at']);
            $table->dropColumn([
                'serving_quantity',
                'serving_unit',
                'grams_per_serving',
                'use_count',
                'last_used_at',
            ]);
        });

        Schema::dropIfExists('calorie_profiles');
    }
};
