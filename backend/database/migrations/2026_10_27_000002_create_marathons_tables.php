<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('marathons', function (Blueprint $table): void {
            $table->id();
            $table->string('title');
            $table->text('description')->nullable();
            // Theme key shared with the app (colours, art and the walker kit).
            $table->string('theme', 40);
            $table->decimal('distance_km', 6, 2);
            $table->decimal('price', 10, 2)->default(0);
            $table->string('currency', 3)->default('PHP');
            $table->date('starts_at');
            $table->date('ends_at');
            $table->text('payment_instructions')->nullable();
            $table->boolean('is_published')->default(false);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->index(['is_published', 'starts_at']);
        });

        Schema::create('marathon_registrations', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('marathon_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('full_name');
            $table->string('email');
            $table->string('phone', 40);
            $table->string('shirt_size', 8);
            $table->text('shipping_address');
            // pending_payment -> payment_submitted -> confirmed | rejected
            $table->string('status', 24)->default('pending_payment');
            $table->string('payment_reference', 120)->nullable();
            $table->string('payment_proof_url', 2048)->nullable();
            $table->timestamp('payment_submitted_at')->nullable();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->string('rejection_reason')->nullable();
            $table->unsignedInteger('bib_number')->nullable();
            $table->timestamp('finished_at')->nullable();
            $table->string('certificate_number', 40)->nullable()->unique();
            $table->timestamp('rewards_shipped_at')->nullable();
            $table->timestamps();
            $table->unique(['marathon_id', 'user_id']);
            $table->unique(['marathon_id', 'bib_number']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('marathon_registrations');
        Schema::dropIfExists('marathons');
    }
};
