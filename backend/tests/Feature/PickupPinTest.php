<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Events\OrderUpdated;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PickupPinTest extends TestCase
{
    use DatabaseMigrations;

    private User $owner;

    private User $courier;

    private User $client;

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();
        $this->owner = User::factory()->restaurant()->create();
        $this->courier = User::factory()->courier()->create();
        $this->client = User::factory()->create();
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => $this->owner->id, 'name' => 'Local PIN', 'address' => 'Centro',
            'phone' => '70000000', 'latitude' => 14.1, 'longitude' => -89.1,
        ]);
        $this->order = Order::unguarded(fn () => Order::create([
            'user_id' => $this->client->id, 'restaurant_id' => $restaurant,
            'courier_id' => $this->courier->id, 'status' => OrderStatus::Ready,
            'delivery_address' => 'Casa', 'delivery_latitude' => 14.2, 'delivery_longitude' => -89.2,
            'subtotal' => '4.00', 'delivery_fee' => '2.00', 'courier_fee' => '1.50',
            'platform_fee' => '0.50', 'total' => '6.00', 'idempotency_key' => 'pickup-pin-test',
        ]));
        $this->order->refresh();
        Event::fake();
    }

    public function test_pin_is_generated_encrypted_and_only_visible_to_own_restaurant_when_ready(): void
    {
        $pin = $this->order->pickup_pin;
        $this->assertMatchesRegularExpression('/^[0-9]{6}$/', $pin);
        $this->assertNotSame($pin, DB::table('orders')->value('pickup_pin'));
        $this->assertArrayNotHasKey('pickup_pin', $this->order->toArray());
        Sanctum::actingAs($this->owner);
        $this->getJson('/api/restaurant/orders')->assertOk()->assertJsonPath('orders.0.pickup_pin', $pin);
        Sanctum::actingAs($this->client);
        $this->getJson('/api/orders/'.$this->order->id)->assertOk()->assertJsonMissingPath('order.pickup_pin');
        Sanctum::actingAs($this->courier);
        $this->getJson('/api/courier/orders')->assertOk()->assertJsonMissingPath('orders.0.pickup_pin')
            ->assertJsonPath('orders.0.pickup_pin_required', true);
        $this->assertArrayNotHasKey('pickup_pin', (new OrderUpdated($this->order))->broadcastWith());
        $this->order->status = OrderStatus::PickedUp;
        $this->order->save();
        Sanctum::actingAs($this->owner);
        $this->getJson('/api/restaurant/orders')->assertOk()->assertJsonMissingPath('orders.0.pickup_pin');
    }

    public function test_missing_or_incorrect_pin_cannot_pick_up_and_correct_pin_is_idempotent(): void
    {
        $this->order->pickup_pin = '012345';
        $this->order->save();
        Sanctum::actingAs($this->courier);
        $url = '/api/courier/orders/'.$this->order->id;
        $this->patchJson($url, ['status' => 'picked_up'])->assertUnprocessable();
        $this->patchJson($url, ['status' => 'picked_up', 'pickup_pin' => '12345'])->assertUnprocessable();
        $this->patchJson($url, ['status' => 'picked_up', 'pickup_pin' => '654321'])->assertUnprocessable();
        $this->assertSame(OrderStatus::Ready, $this->order->fresh()->status);
        Event::assertNotDispatched(OrderUpdated::class);
        $this->patchJson($url, ['status' => 'picked_up', 'pickup_pin' => '012345'])->assertOk()
            ->assertJsonPath('order.status', 'picked_up')->assertJsonMissingPath('order.pickup_pin');
        $time = $this->order->fresh()->picked_up_at;
        $this->travel(1)->minutes();
        $this->patchJson($url, ['status' => 'picked_up'])->assertOk();
        $this->assertEquals($time, $this->order->fresh()->picked_up_at);
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
        $this->patchJson($url, ['status' => 'delivered', 'delivery_pin' => $this->order->delivery_pin])->assertOk();
    }

    public function test_five_wrong_attempts_block_even_correct_pin_until_cooldown_expires(): void
    {
        Sanctum::actingAs($this->courier);
        $url = '/api/courier/orders/'.$this->order->id;
        $wrong = $this->order->pickup_pin === '000000' ? '111111' : '000000';
        for ($i = 0; $i < 5; $i++) {
            $this->patchJson($url, ['status' => 'picked_up', 'pickup_pin' => $wrong])->assertUnprocessable();
        }
        $this->patchJson($url, ['status' => 'picked_up', 'pickup_pin' => $this->order->pickup_pin])->assertStatus(429)->assertHeader('Retry-After');
        $this->assertSame(OrderStatus::Ready, $this->order->fresh()->status);
        $this->travel(301)->seconds();
        $this->patchJson($url, ['status' => 'picked_up', 'pickup_pin' => $this->order->pickup_pin])->assertOk();
    }

    public function test_another_courier_or_restaurant_cannot_read_or_confirm_this_pin(): void
    {
        Sanctum::actingAs(User::factory()->courier()->create());
        $this->patchJson('/api/courier/orders/'.$this->order->id, ['status' => 'picked_up', 'pickup_pin' => $this->order->pickup_pin])->assertNotFound();
        $otherOwner = User::factory()->restaurant()->create();
        DB::table('restaurants')->insert([
            'user_id' => $otherOwner->id, 'name' => 'Otro local', 'address' => 'Centro',
            'phone' => '70000001', 'latitude' => 14.1, 'longitude' => -89.1, 'is_active' => true,
        ]);
        Sanctum::actingAs($otherOwner);
        $this->getJson('/api/restaurant/orders')->assertOk()->assertJsonPath('orders', [])
            ->assertDontSee($this->order->pickup_pin);
        $this->patchJson('/api/restaurant/orders/'.$this->order->id, ['status' => 'ready'])->assertNotFound();
        $this->assertSame(OrderStatus::Ready, $this->order->fresh()->status);
    }

    public function test_legacy_orders_finish_without_backfilling_or_requiring_a_pin(): void
    {
        DB::table('orders')->where('id', $this->order->id)->update(['pickup_pin' => null]);
        Sanctum::actingAs($this->courier);
        $this->getJson('/api/courier/orders')->assertOk()->assertJsonPath('orders.0.pickup_pin_required', false);
        $this->patchJson('/api/courier/orders/'.$this->order->id, ['status' => 'picked_up'])->assertOk();
    }
}
