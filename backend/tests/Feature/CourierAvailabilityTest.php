<?php

namespace Tests\Feature;

use App\Events\CouriersUpdated;
use App\Events\OrderUpdated;
use App\Models\Order;
use App\Models\User;
use App\Support\CourierAvailability;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CourierAvailabilityTest extends TestCase
{
    use DatabaseMigrations;

    private User $client;
    private User $courier;
    private array $payload;

    protected function setUp(): void
    {
        parent::setUp();
        $this->freezeTime();
        Cache::flush();
        Event::fake([OrderUpdated::class, CouriersUpdated::class]);
        $this->client = User::factory()->create();
        $this->courier = User::factory()->courier()->create();
        $this->courier->is_available = true;
        $this->courier->save();
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => User::factory()->restaurant()->create()->id,
            'name' => 'Baruk', 'address' => 'Centro', 'phone' => '70000000',
            'latitude' => 14.1, 'longitude' => -89.1, 'is_open' => true, 'is_active' => true,
        ]);
        DB::table('delivery_zones')->insert([
            'name' => 'Zona', 'polygon' => json_encode(['type' => 'Polygon',
                'coordinates' => [[[-90, 14], [-89, 14], [-89, 15], [-90, 15], [-90, 14]]]]),
            'courier_fee' => '1.50', 'platform_fee' => '0.50', 'is_active' => true,
        ]);
        $address = DB::table('addresses')->insertGetId([
            'user_id' => $this->client->id, 'label' => 'Casa', 'address' => 'Casa',
            'latitude' => 14.2, 'longitude' => -89.2,
        ]);
        $product = DB::table('products')->insertGetId([
            'restaurant_id' => $restaurant, 'name' => 'Plato', 'price' => '4.00', 'is_available' => true,
        ]);
        $this->payload = [
            'restaurant_id' => $restaurant, 'address_id' => $address,
            'expected_delivery_fee' => '2.00', 'items' => [['product_id' => $product, 'quantity' => 1]],
            'idempotency_key' => 'availability-order-test',
        ];
        Sanctum::actingAs($this->client);
    }

    private function presence(array $overrides = []): void
    {
        Cache::put(CourierAvailability::key($this->courier->id), $overrides + [
            'latitude' => 14.1, 'longitude' => -89.1,
            'captured_at' => now()->toISOString(), 'received_at' => now()->toISOString(),
        ], now()->addMinutes(5));
    }

    public function test_new_orders_require_a_recent_free_active_courier_near_the_restaurant(): void
    {
        $this->postJson('/api/orders', $this->payload)->assertUnprocessable()->assertJsonValidationErrors('courier');
        foreach ([
            ['latitude' => 14.15], // Más de 5 km, aunque esté en el mismo municipio.
            ['received_at' => now()->subMinutes(2)->toISOString()],
            ['captured_at' => now()->subMinutes(2)->toISOString()],
        ] as $invalid) {
            $this->presence($invalid);
            $this->postJson('/api/orders', $this->payload)->assertUnprocessable()->assertJsonValidationErrors('courier');
        }
        $this->presence(['latitude' => 14.14]); // Menos de 5 km del restaurante.
        foreach (['is_active', 'is_available'] as $field) {
            $this->courier->$field = false;
            $this->courier->save();
            $this->postJson('/api/orders', $this->payload)->assertUnprocessable()->assertJsonValidationErrors('courier');
            $this->courier->$field = true;
            $this->courier->save();
        }
        $this->courier->role = \App\Enums\UserRole::Client;
        $this->courier->save();
        $this->postJson('/api/orders', $this->payload)->assertUnprocessable()->assertJsonValidationErrors('courier');
        $this->courier->role = \App\Enums\UserRole::Courier;
        $this->courier->save();
        $this->assertDatabaseCount('orders', 0);
        Event::assertNotDispatched(OrderUpdated::class);
        $created = $this->postJson('/api/orders', $this->payload)->assertCreated();
        Cache::flush();
        $this->postJson('/api/orders', $this->payload)->assertOk()
            ->assertJsonPath('order.id', $created->json('order.id'))->assertJsonPath('order.total', '6.00');
        $this->assertDatabaseCount('orders', 1);
    }

    public function test_busy_couriers_do_not_enable_checkout_and_cannot_take_or_be_assigned_another_order(): void
    {
        $this->presence();
        $first = $this->postJson('/api/orders', $this->payload)->assertCreated()->json('order.id');
        $secondPayload = array_replace($this->payload, ['idempotency_key' => 'availability-second-order']);
        $second = $this->postJson('/api/orders', $secondPayload)->assertCreated()->json('order.id');
        DB::table('orders')->whereIn('id', [$first, $second])->update(['status' => 'ready']);
        Sanctum::actingAs($this->courier);
        $this->postJson("/api/courier/orders/{$first}/take")->assertOk();
        $this->postJson("/api/courier/orders/{$first}/take")->assertOk();
        $this->postJson("/api/courier/orders/{$second}/take")->assertUnprocessable();
        Sanctum::actingAs($this->client);
        $third = array_replace($this->payload, ['idempotency_key' => 'availability-third-order']);
        $this->postJson('/api/orders', $third)->assertUnprocessable()->assertJsonValidationErrors('courier');
        $this->actingAs(User::factory()->admin()->create(), 'web');
        $this->post("/admin/pedidos/{$second}/motorizado", ['courier_id' => $this->courier->id])
            ->assertSessionHas('error');
        $this->assertNull(Order::findOrFail($second)->courier_id);
        DB::table('orders')->where('id', $first)->update(['status' => 'delivered']);
        Sanctum::actingAs($this->courier);
        $this->postJson("/api/courier/orders/{$second}/take")->assertOk();
        $this->assertDatabaseCount('orders', 2);
    }

    public function test_presence_is_private_validated_expires_and_is_cleared_when_unavailable_or_logged_out(): void
    {
        $point = ['latitude' => 14.1, 'longitude' => -89.1, 'accuracy' => 10,
            'captured_at' => now()->toISOString()];
        $this->patchJson('/api/courier/presence', $point)->assertForbidden();
        Sanctum::actingAs($this->courier);
        $this->patchJson('/api/courier/presence', array_replace($point, ['accuracy' => 101]))->assertUnprocessable();
        $this->patchJson('/api/courier/presence', array_replace($point, [
            'captured_at' => now()->subMinute()->toISOString(),
        ]))->assertUnprocessable();
        $this->patchJson('/api/courier/presence', array_replace($point, [
            'captured_at' => now()->addMinute()->toISOString(),
        ]))->assertUnprocessable();
        $this->patchJson('/api/courier/presence', $point)->assertOk()->assertExactJson(['accepted' => true]);
        $this->patchJson('/api/courier/presence', $point)->assertOk()->assertExactJson(['accepted' => false]);
        $this->patchJson('/api/courier/availability', ['is_available' => false])->assertOk();
        $this->assertNull(Cache::get(CourierAvailability::key($this->courier->id)));
        $this->patchJson('/api/courier/presence', $point)->assertStatus(409);
        $this->patchJson('/api/courier/availability', ['is_available' => true])->assertOk();
        $this->patchJson('/api/courier/presence', $point)->assertOk();
        $this->travel(2)->minutes();
        $this->assertNull(Cache::get(CourierAvailability::key($this->courier->id)));
        $point['captured_at'] = now()->toISOString();
        $this->patchJson('/api/courier/presence', $point)->assertOk();
        $this->postJson('/api/logout')->assertOk();
        $this->assertNull(Cache::get(CourierAvailability::key($this->courier->id)));
        Event::assertNotDispatched(OrderUpdated::class);
        Event::assertNotDispatched(CouriersUpdated::class);
    }
}
