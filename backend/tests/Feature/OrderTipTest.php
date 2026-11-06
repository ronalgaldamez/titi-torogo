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

    public function test_offer_price_is_authoritative_expired_quotes_are_rejected_and_retries_keep_total(): void
    {
        $this->freezeTime();
        $product = \App\Models\Product::findOrFail($this->payload['items'][0]['product_id']);
        $product->offer_enabled = true;
        $product->sale_price = '3.00';
        $product->offer_starts_at = now();
        $product->offer_ends_at = now()->addMinute();
        $product->save();
        $payload = $this->payload;
        $payload['items'][0]['expected_unit_price'] = '0.01';
        $this->postJson('/api/orders', $payload)->assertUnprocessable();
        $this->assertDatabaseCount('orders', 0);
        $payload['items'][0]['expected_unit_price'] = '3.00';
        $this->postJson('/api/orders', $payload)->assertCreated()
            ->assertJsonPath('order.subtotal', '3.00')->assertJsonPath('order.total', '5.00');
        $this->travel(1)->minutes();
        $this->postJson('/api/orders', $payload)->assertOk()->assertJsonPath('order.total', '5.00');
        $payload['idempotency_key'] = 'offer-after-expiration';
        $this->postJson('/api/orders', $payload)->assertUnprocessable()->assertJsonValidationErrors('items');
        $this->assertDatabaseCount('orders', 1);
        $payload['items'][0]['expected_unit_price'] = '4.00';
        $this->postJson('/api/orders', $payload)->assertCreated()->assertJsonPath('order.total', '6.00');
    }

    public function test_new_order_has_five_minutes_and_retry_does_not_extend_deadline(): void
    {
        $this->freezeTime();
        $response = $this->postJson('/api/orders', $this->payload)->assertCreated();
        $deadline = $response->json('order.acceptance_expires_at');
        $this->assertSame(now()->addMinutes(5)->toIso8601String(), $deadline);
        $this->travel(2)->minutes();
        $this->postJson('/api/orders', $this->payload)->assertOk()
            ->assertJsonPath('order.acceptance_expires_at', $deadline);
        $this->assertDatabaseCount('orders', 1);
    }

    public function test_delivery_quote_must_match_and_retries_keep_the_original_charge(): void
    {
        $payload = $this->payload;
        $payload['expected_delivery_fee'] = '0.01';
        $this->postJson('/api/orders', $payload)->assertUnprocessable()
            ->assertJsonValidationErrors('expected_delivery_fee');
        $this->assertDatabaseCount('orders', 0);
        unset($payload['expected_delivery_fee']);
        $this->postJson('/api/orders', $payload)->assertUnprocessable();
        $payload = $this->payload;
        DB::table('restaurants')->where('id', $payload['restaurant_id'])->update(['delivery_fee' => '3.00']);
        $this->postJson('/api/orders', $payload)->assertUnprocessable();
        $this->assertDatabaseCount('orders', 0);
        $payload['expected_delivery_fee'] = '3.00';
        $response = $this->postJson('/api/orders', $payload)->assertCreated()
            ->assertJsonPath('order.delivery_fee', '3.00')->assertJsonPath('order.total', '7.00');
        DB::table('restaurants')->where('id', $payload['restaurant_id'])->update(['delivery_fee' => '4.00']);
        $this->postJson('/api/orders', $payload)->assertOk()
            ->assertJsonPath('order.id', $response->json('order.id'))->assertJsonPath('order.total', '7.00');
        $this->assertDatabaseCount('orders', 1);
    }

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
            'expected_delivery_fee' => '2.00',
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
