<?php

namespace Tests\Feature;

use App\Models\DailyTracker;
use App\Models\Marathon;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MarathonTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow(null);
        parent::tearDown();
    }

    private function admin(): User
    {
        return User::factory()->create(['is_admin' => true]);
    }

    private function marathon(array $overrides = []): Marathon
    {
        return Marathon::create(array_merge([
            'title' => 'Sunrise 10K',
            'theme' => 'sunrise',
            'distance_km' => 10,
            'price' => 499,
            'starts_at' => '2026-11-01',
            'ends_at' => '2026-11-30',
            'payment_instructions' => 'GCash 0917 000 0000',
            'is_published' => true,
        ], $overrides));
    }

    private function form(): array
    {
        return [
            'full_name' => 'Ana Reyes',
            'email' => 'ana@example.com',
            'phone' => '09170000000',
            'shirt_size' => 'M',
            'shipping_address' => '1 Rizal St, Manila',
        ];
    }

    public function test_admins_create_marathons_and_only_published_ones_are_listed(): void
    {
        Sanctum::actingAs($this->admin());
        $this->postJson('/api/admin/marathons', [
            'title' => 'Ocean Half',
            'theme' => 'ocean',
            'distance_km' => 21.1,
            'price' => 799,
            'starts_at' => '2026-12-01',
            'ends_at' => '2026-12-31',
        ])->assertCreated()->assertJsonPath('marathon.isPublished', false);
        $this->postJson('/api/admin/marathons', ['title' => 'Bad', 'theme' => 'lava'])->assertStatus(422);
        $this->marathon();

        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/admin/marathons', ['title' => 'x'])->assertForbidden();
        $this->getJson('/api/marathons')
            ->assertOk()
            ->assertJsonCount(1, 'marathons')
            ->assertJsonPath('marathons.0.title', 'Sunrise 10K')
            ->assertJsonPath('marathons.0.myRegistration', null);
    }

    public function test_join_pay_get_approved_and_receive_a_bib(): void
    {
        Carbon::setTestNow('2026-10-27 09:00:00');
        $marathon = $this->marathon();
        $runner = User::factory()->create();
        Sanctum::actingAs($runner);

        $this->postJson("/api/marathons/{$marathon->id}/register", $this->form())
            ->assertCreated()
            ->assertJsonPath('marathon.phase', 'upcoming')
            ->assertJsonPath('marathon.myRegistration.status', 'pending_payment');
        $this->postJson("/api/marathons/{$marathon->id}/register", $this->form())->assertStatus(409);
        $this->postJson("/api/marathons/{$marathon->id}/register", ['shirt_size' => 'XXXXL'] + $this->form())->assertStatus(422);

        $this->postJson("/api/marathons/{$marathon->id}/payment", [
            'payment_reference' => 'GC-123',
            'payment_proof_url' => 'https://cdn.example.com/proof.jpg',
        ])->assertOk()->assertJsonPath('marathon.myRegistration.status', 'payment_submitted');

        $registrationId = $marathon->registrations()->first()->id;
        Sanctum::actingAs($this->admin());
        $this->getJson("/api/admin/marathons/{$marathon->id}/registrations")
            ->assertJsonPath('registrations.0.paymentReference', 'GC-123');
        $this->postJson("/api/admin/marathon-registrations/{$registrationId}/review", ['action' => 'reject'])
            ->assertStatus(422);
        $this->postJson("/api/admin/marathon-registrations/{$registrationId}/review", ['action' => 'approve'])
            ->assertOk()
            ->assertJsonPath('status', 'confirmed')
            ->assertJsonPath('bibNumber', 1);
    }

    public function test_a_rejected_payment_can_be_resubmitted(): void
    {
        $marathon = $this->marathon();
        $runner = User::factory()->create();
        Sanctum::actingAs($runner);
        $this->postJson("/api/marathons/{$marathon->id}/register", $this->form());
        $registration = $marathon->registrations()->first();

        Sanctum::actingAs($this->admin());
        $this->postJson("/api/admin/marathon-registrations/{$registration->id}/review", [
            'action' => 'reject',
            'reason' => 'Screenshot unreadable',
        ])->assertJsonPath('status', 'rejected');

        Sanctum::actingAs($runner);
        $this->getJson("/api/marathons/{$marathon->id}")
            ->assertJsonPath('marathon.myRegistration.rejectionReason', 'Screenshot unreadable');
        $this->postJson("/api/marathons/{$marathon->id}/payment", [
            'payment_reference' => 'GC-456',
            'payment_proof_url' => 'https://cdn.example.com/proof2.jpg',
        ])->assertJsonPath('marathon.myRegistration.status', 'payment_submitted');
    }

    public function test_free_marathons_confirm_right_away(): void
    {
        $marathon = $this->marathon(['price' => 0]);
        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/marathons/{$marathon->id}/register", $this->form())
            ->assertJsonPath('marathon.myRegistration.status', 'confirmed')
            ->assertJsonPath('marathon.myRegistration.bibNumber', 1);
    }

    public function test_steps_during_the_marathon_count_toward_the_finish_and_earn_a_certificate(): void
    {
        $marathon = $this->marathon(['price' => 0, 'distance_km' => 10]);
        $runner = User::factory()->create();
        Sanctum::actingAs($runner);
        $this->postJson("/api/marathons/{$marathon->id}/register", $this->form());

        $log = fn (string $date, int $steps) => DailyTracker::create([
            'user_id' => (string) $runner->id, 'username' => 'Ana', 'date' => $date, 'step_count' => $steps,
        ]);
        $log('2026-10-31', 50000); // before the start: doesn't count
        $log('2026-11-02', 8000);  // 8000 * 0.67 m = 5.36 km
        $log('2026-11-03', 7000);  // 15000 * 0.67 m = 10.05 km

        Carbon::setTestNow('2026-10-30 09:00:00');
        $this->getJson("/api/marathons/{$marathon->id}")
            ->assertJsonPath('marathon.phase', 'upcoming')
            ->assertJsonPath('marathon.myRegistration.progress.km', 0);
        $this->getJson("/api/marathons/{$marathon->id}/certificate")->assertNotFound();

        Carbon::setTestNow('2026-11-02 20:00:00');
        $this->getJson("/api/marathons/{$marathon->id}")
            ->assertJsonPath('marathon.phase', 'ongoing')
            ->assertJsonPath('marathon.myRegistration.progress.km', 5.36)
            ->assertJsonPath('marathon.myRegistration.progress.finished', false);

        Carbon::setTestNow('2026-11-03 20:00:00');
        $this->getJson("/api/marathons/{$marathon->id}")
            ->assertJsonPath('marathon.myRegistration.progress.finished', true);
        $this->getJson("/api/marathons/{$marathon->id}/certificate")
            ->assertOk()
            ->assertJsonPath('certificate.runnerName', 'Ana Reyes')
            ->assertJsonPath('certificate.number', sprintf('IU-%04d-%05d', $marathon->id, 1));
    }

    public function test_registration_closes_after_the_marathon_ends(): void
    {
        Carbon::setTestNow('2026-12-05 09:00:00');
        $marathon = $this->marathon();
        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/marathons/{$marathon->id}/register", $this->form())->assertStatus(422);
    }

    public function test_only_confirmed_runners_can_wear_the_marathon_kit(): void
    {
        $marathon = $this->marathon(['price' => 0]);
        $runner = User::factory()->create();
        Sanctum::actingAs($runner);
        $look = [
            'skin' => 0xFFE0A47E, 'hairStyle' => 'short', 'hair' => 0xFF3B2416, 'top' => 'tee',
            'topColor' => 0xFFFF7043, 'bottom' => 'shorts', 'bottomColor' => 0xFF37474F,
            'shoes' => 0xFFF5F5F5, 'accessory' => 'none', 'kit' => 'sunrise', 'bib' => 1,
        ];

        $this->postJson('/api/walker-look', ['look' => $look])->assertStatus(422);

        $this->postJson("/api/marathons/{$marathon->id}/register", $this->form());
        $this->postJson('/api/walker-look', ['look' => $look])
            ->assertOk()
            ->assertJsonPath('look.kit', 'sunrise')
            ->assertJsonPath('look.bib', 1);
        $this->postJson('/api/walker-look', ['look' => ['bib' => 7] + $look])->assertStatus(422);
        $this->postJson('/api/walker-look', ['look' => ['kit' => 'ocean'] + $look])->assertStatus(422);
    }

    public function test_the_race_leaderboard_ranks_confirmed_runners_by_distance(): void
    {
        $marathon = $this->marathon(['price' => 0, 'distance_km' => 10]);
        $join = function (string $name, int $steps) use ($marathon): User {
            $user = User::factory()->create(['name' => $name]);
            Sanctum::actingAs($user);
            $this->postJson("/api/marathons/{$marathon->id}/register", ['full_name' => $name] + $this->form());
            DailyTracker::create([
                'user_id' => (string) $user->id, 'username' => $name,
                'date' => '2026-11-02', 'step_count' => $steps,
            ]);

            return $user;
        };
        $join('Ben', 6000);   // 4.02 km
        $join('Ana', 16000);  // 10.72 km: finisher
        $cara = $join('Cara', 9000); // 6.03 km
        $outsider = User::factory()->create(['name' => 'Dan']);
        DailyTracker::create([
            'user_id' => (string) $outsider->id, 'username' => 'Dan',
            'date' => '2026-11-02', 'step_count' => 99999,
        ]);

        Carbon::setTestNow('2026-11-03 09:00:00');
        Sanctum::actingAs($cara);
        $response = $this->getJson("/api/marathons/{$marathon->id}/leaderboard")
            ->assertOk()
            ->assertJsonPath('marathon.myRegistration.status', 'confirmed')
            ->assertJsonCount(3, 'runners');

        $runners = collect($response->json('runners'));
        $this->assertSame(['Ana', 'Cara', 'Ben'], $runners->pluck('name')->all());
        $this->assertSame([1, 2, 3], $runners->pluck('rank')->all());
        $this->assertTrue($runners[0]['finished']);
        $this->assertSame(6.03, $runners[1]['km']);
        $this->assertNotNull($runners[1]['bibNumber']);
    }

    public function test_an_unpublished_marathon_has_no_public_leaderboard(): void
    {
        $marathon = $this->marathon(['is_published' => false]);
        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/marathons/{$marathon->id}/leaderboard")->assertNotFound();
    }
}
