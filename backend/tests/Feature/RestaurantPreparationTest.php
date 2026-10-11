<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RestaurantPreparationTest extends TestCase
{
    use DatabaseMigrations;

    private function restaurant(User $owner): int
    {
        return DB::table('restaurants')->insertGetId([
            'user_id' => $owner->id, 'name' => 'Local', 'address' => 'Centro',
            'phone' => '70000000', 'latitude' => 14.1, 'longitude' => -89.1,
            'prep_time_minutes' => 30, 'is_open' => true,
        ]);
    }

    public function test_range_preserves_old_times_and_busy_increases_both_limits(): void
    {
        $owner = User::factory()->restaurant()->create();
        $id = $this->restaurant($owner);
        $other = $this->restaurant(User::factory()->restaurant()->create());
        Sanctum::actingAs($owner);
        $this->getJson('/api/restaurant/status')->assertOk()
            ->assertJsonPath('restaurant.prep_time_min_minutes', 30)
            ->assertJsonPath('restaurant.prep_time_max_minutes', 30);
        $this->patchJson('/api/restaurant/status', [
            'is_open' => true, 'is_busy' => false,
            'prep_time_min_minutes' => 15, 'prep_time_max_minutes' => 25,
        ])->assertOk()->assertJsonPath('restaurant.estimated_prep_min_minutes', 15)
            ->assertJsonPath('restaurant.estimated_prep_max_minutes', 25);
        $this->patchJson('/api/restaurant/status', ['is_open' => true, 'is_busy' => true])
            ->assertOk()->assertJsonPath('restaurant.estimated_prep_min_minutes', 23)
            ->assertJsonPath('restaurant.estimated_prep_max_minutes', 38)
            ->assertJsonPath('restaurant.prep_time_min_minutes', 15)
            ->assertJsonPath('restaurant.prep_time_max_minutes', 25);
        $this->assertDatabaseHas('restaurants', ['id' => $id, 'prep_time_min_minutes' => 15, 'prep_time_minutes' => 25]);
        $this->assertDatabaseHas('restaurants', ['id' => $other, 'prep_time_min_minutes' => null, 'prep_time_minutes' => 30]);
    }

    public function test_invalid_or_incomplete_ranges_do_not_change_the_local(): void
    {
        $owner = User::factory()->restaurant()->create();
        $id = $this->restaurant($owner);
        Sanctum::actingAs($owner);
        foreach ([
            ['prep_time_min_minutes' => 0, 'prep_time_max_minutes' => 25],
            ['prep_time_min_minutes' => 1, 'prep_time_max_minutes' => 25],
            ['prep_time_min_minutes' => 9, 'prep_time_max_minutes' => 25],
            ['prep_time_min_minutes' => 10, 'prep_time_max_minutes' => 46],
            ['prep_time_min_minutes' => 40, 'prep_time_max_minutes' => 20],
            ['prep_time_min_minutes' => 15, 'prep_time_max_minutes' => 181],
            ['prep_time_min_minutes' => 1.5, 'prep_time_max_minutes' => 25],
            ['prep_time_min_minutes' => 15],
            ['prep_time_max_minutes' => 25],
        ] as $range) {
            $this->patchJson('/api/restaurant/status', array_merge([
                'is_open' => false, 'is_busy' => true,
            ], $range))->assertUnprocessable();
        }
        $this->assertDatabaseHas('restaurants', ['id' => $id, 'prep_time_minutes' => 30, 'is_open' => true, 'is_busy' => false]);
    }

    public function test_busy_preparation_never_exceeds_45_minutes(): void
    {
        $owner = User::factory()->restaurant()->create();
        $this->restaurant($owner);
        Sanctum::actingAs($owner);
        foreach ([[10, 20, 15, 30], [20, 30, 30, 45], [30, 45, 45, 45]] as [$minimum, $maximum, $expectedMin, $expectedMax]) {
            $this->patchJson('/api/restaurant/status', [
                'is_open' => true, 'is_busy' => true,
                'prep_time_min_minutes' => $minimum, 'prep_time_max_minutes' => $maximum,
            ])->assertOk()->assertJsonPath('restaurant.estimated_prep_min_minutes', $expectedMin)
                ->assertJsonPath('restaurant.estimated_prep_max_minutes', $expectedMax);
        }
    }

    public function test_old_out_of_range_times_are_presented_within_limits(): void
    {
        $owner = User::factory()->restaurant()->create();
        $id = $this->restaurant($owner);
        Sanctum::actingAs($owner);
        DB::table('restaurants')->where('id', $id)->update(['prep_time_minutes' => 1]);
        $this->getJson('/api/restaurant/status')->assertOk()
            ->assertJsonPath('restaurant.prep_time_min_minutes', 10)
            ->assertJsonPath('restaurant.prep_time_max_minutes', 10);
    }

    public function test_preparation_requires_a_restaurant_account(): void
    {
        $range = ['is_open' => true, 'is_busy' => false, 'prep_time_min_minutes' => 15, 'prep_time_max_minutes' => 25];
        $this->patchJson('/api/restaurant/status', $range)->assertUnauthorized();
        Sanctum::actingAs(User::factory()->create());
        $this->patchJson('/api/restaurant/status', $range)->assertForbidden();
    }
}
