<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RestaurantHistoryTest extends TestCase
{
    use DatabaseMigrations;

    public function test_history_is_private_filters_closing_dates_and_paginates(): void
    {
        config(['app.timezone' => 'America/El_Salvador']);
        $this->travelTo(Carbon::parse('2026-10-11 12:00:00', 'America/El_Salvador'));
        $owner = User::factory()->restaurant()->create();
        $other = User::factory()->restaurant()->create();
        $client = User::factory()->create();
        $restaurants = [];
        foreach ([$owner, $other] as $user) {
            $restaurants[] = DB::table('restaurants')->insertGetId([
                'user_id' => $user->id, 'name' => 'Local', 'address' => 'Centro',
                'phone' => '70000000', 'latitude' => 14.1, 'longitude' => -89.1,
            ]);
        }
        foreach ([
            [0, 'delivered', '2026-10-11 00:00:00'],
            [0, 'rejected', '2026-10-11 10:00:00'],
            [0, 'cancelled', '2026-10-10 23:59:59'],
            [0, 'delivered', '2026-10-05 00:00:00'],
            [0, 'delivered', '2026-10-04 23:59:59'],
            [0, 'delivered', '2026-10-12 00:00:00'],
            [0, 'pending', null],
            [1, 'delivered', '2026-10-11 11:00:00'],
        ] as $index => [$restaurant, $status, $closed]) {
            DB::table('orders')->insert([
                'user_id' => $client->id, 'restaurant_id' => $restaurants[$restaurant],
                'status' => $status, 'delivery_address' => 'Casa',
                'delivery_latitude' => 14.2, 'delivery_longitude' => -89.2,
                'subtotal' => '3.00', 'delivery_fee' => '2.00', 'courier_fee' => '1.50',
                'platform_fee' => '0.50', 'tip_amount' => '1.00', 'total' => '6.00',
                'idempotency_key' => 'restaurant-history-'.$index,
                'created_at' => '2026-09-01 10:00:00',
                'delivered_at' => $status === 'delivered' ? $closed : null,
                'cancelled_at' => in_array($status, ['cancelled', 'rejected'], true) ? $closed : null,
            ]);
        }
        Sanctum::actingAs($owner);
        $this->getJson('/api/restaurant/orders?scope=history&period=today')->assertOk()
            ->assertJsonCount(2, 'orders')->assertJsonPath('orders.0.status', 'rejected')
            ->assertJsonPath('orders.1.tip_amount', '1.00');
        $this->getJson('/api/restaurant/orders?scope=history&period=week')->assertOk()->assertJsonCount(4, 'orders');
        $this->getJson('/api/restaurant/orders?scope=history&period=all')->assertOk()->assertJsonCount(6, 'orders');
        $this->getJson('/api/restaurant/orders?scope=history&period=all&status=rejected')->assertOk()->assertJsonCount(1, 'orders');
        $this->getJson('/api/restaurant/orders')->assertOk()->assertJsonCount(1, 'orders')->assertJsonPath('orders.0.status', 'pending');
        $row = (array) DB::table('orders')->where('idempotency_key', 'restaurant-history-0')->first();
        unset($row['id']);
        for ($index = 0; $index < 21; $index++) {
            $row['idempotency_key'] = 'restaurant-history-page-'.$index;
            DB::table('orders')->insert($row);
        }
        $this->getJson('/api/restaurant/orders?scope=history&period=today')->assertOk()
            ->assertJsonCount(20, 'orders')->assertJsonPath('pagination.total', 23)
            ->assertJsonPath('pagination.last_page', 2);
        $this->getJson('/api/restaurant/orders?scope=history&period=today&page=2')->assertOk()->assertJsonCount(3, 'orders');
        foreach (['status=pending', 'period=invalid', 'page=0'] as $query) {
            $this->getJson('/api/restaurant/orders?scope=history&'.$query)->assertUnprocessable();
        }
    }

    public function test_history_requires_a_restaurant_account(): void
    {
        $this->getJson('/api/restaurant/orders?scope=history')->assertUnauthorized();
        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/restaurant/orders?scope=history')->assertForbidden();
    }
}
