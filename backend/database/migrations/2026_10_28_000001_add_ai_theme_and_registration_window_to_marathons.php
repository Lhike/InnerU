<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('marathons', function (Blueprint $table): void {
            // When people can join. Null opens right away / closes when the race ends.
            $table->date('registration_opens_at')->nullable()->after('ends_at');
            $table->date('registration_closes_at')->nullable()->after('registration_opens_at');
            // QR code runners scan to pay the entry fee.
            $table->string('payment_qr_url', 2048)->nullable()->after('payment_instructions');
            // Colours and kit of a 'custom' (AI-made) theme.
            $table->json('theme_data')->nullable()->after('theme');
            $table->string('kit_image_url', 2048)->nullable()->after('theme_data');
        });
    }

    public function down(): void
    {
        Schema::table('marathons', function (Blueprint $table): void {
            $table->dropColumn(['registration_opens_at', 'registration_closes_at', 'payment_qr_url', 'theme_data', 'kit_image_url']);
        });
    }
};
