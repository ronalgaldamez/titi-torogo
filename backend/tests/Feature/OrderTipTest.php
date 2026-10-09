<?php

namespace Tests\Feature;

use App\Events\CouriersUpdated;
use App\Events\OrderUpdated;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderTipTest extends TestCase
{
    use DatabaseMigrations;

    private array $payload;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake([OrderUpdated::class, CouriersUpdated::class]);
        $client = User::factory()->create();
        $owner = User::factory()->restaurant()->create();
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => $owner->id, 'name' => 'Restaurante', 'address' => 'Centro',
            'phone' => '70000000', 'latitude' => 14.1, 'longitude' => -89.1,
            'is_open' => true, 'is_active' => true,
        ]);
        DB::table('delivery_zones')->insert([
            'name' => 'Zona', 'polygon' => json_encode(['type' => 'Polygon',
                'coordinates' => [[[-90, 14], [-89, 14], [-89, 15], [-90, 15], [-90, 14]]]]),
            'courier_fee' => '1.50', 'platform_fee' => '0.50', 'is_active' => true,
        ]);
        $address = DB::table('addresses')->insertGetId([
            'user_id' => $client->id, 'label' => 'Casa', 'address' => 'Casa',
            'latitude' => 14.2, 'longitude' => -89.2,
        ]);
        $product = DB::table('products')->insertGetId([
            'restaurant_id' => $restaurant, 'name' => 'Sub', 'price' => '4.00',
            'is_available' => true,
        ]);
        Sanctum::actingAs($client);
        $this->payload = [
            'restaurant_id' => $restaurant, 'address_id' => $address,
            'items' => [['product_id' => $product, 'quantity' => 1]],
            'idempotency_key' => 'tip-test-order',
        ];
    }

    public function test_tip_is_separate_and_retries_and_recovery_keep_original_total(): void
    {
        $payload = $this->payload + ['tip_amount' => '1.25', 'total' => '0.01'];
        $response = $this->postJson('/api/orders', $payload)->assertCreated()
            ->assertJsonPath('order.total', '7.25')->assertJsonPath('order.tip_amount', '1.25')
            ->assertJsonPath('order.courier_fee', '1.50')->assertJsonPath('order.delivery_fee', '2.00');
        $id = $response->json('order.id');
        $payload['tip_amount'] = '2.00';
        $this->postJson('/api/orders', $payload)->assertOk()
            ->assertJsonPath('order.id', $id)->assertJsonPath('order.total', '7.25')
            ->assertJsonPath('order.tip_amount', '1.25');
        $this->postJson('/api/orders/recover', ['idempotency_key' => $payload['idempotency_key']])
            ->assertOk()->assertJsonPath('order.tip_amount', '1.25')->assertJsonPath('order.total', '7.25');
        $this->assertDatabaseCount('orders', 1);
    }

    public function test_no_tip_keeps_previous_total_and_invalid_amounts_are_rejected(): void
    {
        foreach (['-1.00', '1.234', '100.01', 'abc', '1e2', '1,25', null, 1.25] as $tip) {
            $this->postJson('/api/orders', $this->payload + ['tip_amount' => $tip])
                ->assertUnprocessable()->assertJsonValidationErrors('tip_amount');
        }
        $this->assertDatabaseCount('orders', 0);
        $this->postJson('/api/orders', $this->payload)->assertCreated()
            ->assertJsonPath('order.tip_amount', '0.00')->assertJsonPath('order.total', '6.00');
        $payload = $this->payload;
        $payload['idempotency_key'] = 'tip-max-order';
        $this->postJson('/api/orders', $payload + ['tip_amount' => '100.00'])->assertCreated()
            ->assertJsonPath('order.total', '106.00');
    }
}
