<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CourierHistoryTest extends TestCase
{
    use DatabaseMigrations;

    public function test_history_filters_closed_orders_and_preserves_period_totals(): void
    {
        config(['app.timezone' => 'America/El_Salvador']);
        $this->travelTo(Carbon::parse('2026-10-07 12:00:00', 'America/El_Salvador'));
        $courier = User::factory()->courier()->create();
        $other = User::factory()->courier()->create();
        $client = User::factory()->create();
        $owner = User::factory()->restaurant()->create();
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => $owner->id, 'name' => 'Restaurante', 'address' => 'Centro',
            'phone' => '70000000', 'latitude' => 14.1, 'longitude' => -89.1,
        ]);
        foreach ([
            [$courier->id, 'delivered', '2026-10-07 00:00:00', '1.10'],
            [$courier->id, 'delivered', '2026-10-07 23:59:59', '2.20'],
            [$courier->id, 'delivered', '2026-10-06 23:59:59', '8.00'],
            [$courier->id, 'delivered', '2026-10-08 00:00:00', '8.00'],
            [$courier->id, 'picked_up', null, '8.00'],
            [$courier->id, 'cancelled', '2026-10-07 10:00:00', '8.00'],
            [$other->id, 'delivered', '2026-10-07 10:00:00', '8.00'],
        ] as $index => [$courierId, $status, $deliveredAt, $fee]) {
            DB::table('orders')->insert([
                'user_id' => $client->id, 'restaurant_id' => $restaurant,
                'courier_id' => $courierId, 'status' => $status,
                'delivery_address' => 'Casa', 'delivery_latitude' => 14.2,
                'delivery_longitude' => -89.2, 'subtotal' => '20.00',
                'delivery_fee' => '10.00', 'courier_fee' => $fee,
                'platform_fee' => '2.00', 'tip_amount' => '0.50', 'total' => '30.50',
                'idempotency_key' => "history-$index",
                'delivered_at' => $status === 'delivered' ? $deliveredAt : null,
                'cancelled_at' => $status === 'cancelled' ? $deliveredAt : null,
                'created_at' => '2026-10-06 15:00:00',
            ]);
        }
        Sanctum::actingAs($courier);
        $this->getJson('/api/courier/history')->assertOk()
            ->assertJsonCount(3, 'orders')->assertJsonPath('orders.0.courier_fee', '2.20')
            ->assertJsonPath('summary.deliveries', 2)->assertJsonPath('summary.earnings', '4.30');
        $this->getJson('/api/courier/history?status=cancelled')->assertOk()
            ->assertJsonCount(1, 'orders')->assertJsonPath('orders.0.status', 'cancelled')
            ->assertJsonPath('summary.earnings', '4.30');
        foreach (['week', 'month'] as $period) {
            $this->getJson('/api/courier/history?period='.$period)->assertOk()
                ->assertJsonCount(4, 'orders')->assertJsonPath('summary.earnings', '12.80');
        }
        $row = (array) DB::table('orders')->where('idempotency_key', 'history-0')->first();
        unset($row['id']);
        for ($i = 0; $i < 21; $i++) {
            $row['idempotency_key'] = 'history-page-'.$i;
            DB::table('orders')->insert($row);
        }
        $this->getJson('/api/courier/history')->assertOk()
            ->assertJsonCount(20, 'orders')->assertJsonPath('next_page', 2);
        $this->getJson('/api/courier/history?page=2')->assertOk()
            ->assertJsonCount(4, 'orders')->assertJsonPath('next_page', null);
        foreach (['period=invalid', 'status=picked_up', 'page=0'] as $query) {
            $this->getJson('/api/courier/history?'.$query)->assertUnprocessable();
        }
        Sanctum::actingAs(User::factory()->courier()->create());
        $this->getJson('/api/courier/history')->assertOk()->assertJsonCount(0, 'orders')
            ->assertJsonPath('summary.earnings', '0.00');
    }

    public function test_history_requires_a_courier_account(): void
    {
        $this->getJson('/api/courier/history')->assertUnauthorized();
        foreach ([User::factory()->create(), User::factory()->restaurant()->create()] as $user) {
            Sanctum::actingAs($user);
            $this->getJson('/api/courier/history')->assertForbidden();
        }
    }
}
