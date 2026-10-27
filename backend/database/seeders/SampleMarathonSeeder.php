<?php

namespace Database\Seeders;

use App\Models\Marathon;
use Illuminate\Database\Seeder;

/**
 * A sample marathon for trying the feature locally:
 *   php artisan db:seed --class=SampleMarathonSeeder
 * Not part of DatabaseSeeder, so it never runs on its own.
 */
class SampleMarathonSeeder extends Seeder
{
    public const TITLE = 'Under the Sea 5K (Sample)';

    public function run(): void
    {
        Marathon::updateOrCreate(
            ['title' => self::TITLE],
            [
                'description' => 'A test marathon to try joining, paying, the race view and '
                    .'certificates. Dive in and walk 5 km anywhere: every step counts.',
                'theme' => 'undersea',
                'distance_km' => 5,
                'price' => 99,
                'currency' => 'PHP',
                'starts_at' => now()->toDateString(),
                'ends_at' => now()->addDays(30)->toDateString(),
                'payment_instructions' => "TEST ONLY: don't send real money.\n"
                    .'Upload any screenshot and use any reference number.',
                'is_published' => true,
            ],
        );
    }
}
