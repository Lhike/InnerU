<?php

namespace Tests\Feature;

use App\Models\Company;
use App\Models\DailyTracker;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WalkerLookTest extends TestCase
{
    use RefreshDatabase;

    private function look(array $overrides = []): array
    {
        return array_merge([
            'skin' => 0xFFE0A47E,
            'hairStyle' => 'ponytail',
            'hair' => 0xFF3B2416,
            'top' => 'hoodie',
            'topColor' => 0xFF7C4DFF,
            'bottom' => 'shorts',
            'bottomColor' => 0xFF37474F,
            'shoes' => 0xFFF5F5F5,
            'accessory' => 'headphones',
        ], $overrides);
    }

    public function test_a_user_saves_and_reads_their_walker(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->getJson('/api/walker-look')->assertOk()->assertJsonPath('look', null);

        $this->postJson('/api/walker-look', ['look' => $this->look() + ['extra' => 'ignored']])
            ->assertOk()
            ->assertJsonPath('look.hairStyle', 'ponytail')
            ->assertJsonPath('look.topColor', 0xFF7C4DFF)
            ->assertJsonMissingPath('look.extra');

        $this->getJson('/api/walker-look')->assertJsonPath('look.accessory', 'headphones');
    }

    public function test_invalid_walkers_are_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/walker-look', ['look' => $this->look(['hairStyle' => 'mohawk'])])
            ->assertStatus(422);
        $this->postJson('/api/walker-look', ['look' => $this->look(['skin' => -1])])
            ->assertStatus(422);
        $this->postJson('/api/walker-look', ['look' => $this->look(['accessory' => 'cape'])])
            ->assertStatus(422);
        $this->postJson('/api/walker-look', ['look' => array_diff_key($this->look(), ['top' => 1])])
            ->assertStatus(422);
    }

    public function test_company_members_see_each_others_walkers_in_the_race(): void
    {
        $company = Company::create(['id' => (string) Str::uuid(), 'name' => 'Acme', 'code' => 'ACME1']);
        $member = fn (string $name) => User::factory()->create([
            'name' => $name,
            'company_id' => $company->id,
            'company_code' => $company->code,
            'company_name' => $company->name,
        ]);
        $ana = $member('Ana');
        $ben = $member('Ben');

        Sanctum::actingAs($ben);
        $this->postJson('/api/walker-look', ['look' => $this->look(['hairStyle' => 'curly'])])->assertOk();

        DailyTracker::create(['user_id' => (string) $ben->id, 'username' => 'Ben', 'date' => '2026-10-27', 'step_count' => 5000]);

        Sanctum::actingAs($ana);
        $entries = collect($this->getJson('/api/leaderboard/steps?period=today&date=2026-10-27')
            ->assertOk()
            ->json('entries'))
            ->keyBy('name');

        $this->assertSame('curly', $entries['Ben']['walkerLook']['hairStyle']);
        $this->assertNull($entries['Ana']['walkerLook']);
    }
}
