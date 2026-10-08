<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CourierSummaryTest extends TestCase
{
    use DatabaseMigrations;

    public function test_summary_counts_only_own_deliveries_completed_today(): void
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
                'platform_fee' => '2.00', 'total' => '30.00',
                'idempotency_key' => "summary-$index", 'delivered_at' => $deliveredAt,
                'created_at' => '2026-10-06 15:00:00',
            ]);
        }
        Sanctum::actingAs($courier);
        $this->getJson('/api/courier/summary')->assertOk()->assertExactJson([
            'date' => '2026-10-07', 'deliveries' => 2, 'earnings' => '3.30',
        ]);
        $this->travel(1)->days();
        $this->getJson('/api/courier/summary')->assertOk()->assertJsonPath('deliveries', 1);
        Sanctum::actingAs(User::factory()->courier()->create());
        $this->getJson('/api/courier/summary')->assertOk()->assertExactJson([
            'date' => '2026-10-08', 'deliveries' => 0, 'earnings' => '0.00',
        ]);
    }

    public function test_summary_requires_a_courier_account(): void
    {
        $this->getJson('/api/courier/summary')->assertUnauthorized();
        foreach ([User::factory()->create(), User::factory()->restaurant()->create()] as $user) {
            Sanctum::actingAs($user);
            $this->getJson('/api/courier/summary')->assertForbidden();
        }
    }
}
