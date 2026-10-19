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

class CustomerCancellationTest extends TestCase
{
    use DatabaseMigrations;

    private function order(string $status = 'pending'): Order
    {
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => User::factory()->restaurant()->create()->id,
            'name' => 'Local', 'address' => 'Centro', 'phone' => '70000000',
            'latitude' => 14.1, 'longitude' => -89.1,
        ]);
        $id = DB::table('orders')->insertGetId([
            'user_id' => User::factory()->create()->id, 'restaurant_id' => $restaurant,
            'status' => $status, 'delivery_address' => 'Casa',
            'delivery_latitude' => 14.2, 'delivery_longitude' => -89.2,
            'subtotal' => '3.00', 'delivery_fee' => '2.00', 'courier_fee' => '1.50',
            'platform_fee' => '0.50', 'tip_amount' => '1.00', 'total' => '6.00',
            'idempotency_key' => fake()->uuid(), 'created_at' => now(),
            'acceptance_expires_at' => now()->addMinutes(5),
        ]);

        return Order::findOrFail($id);
    }

    public function test_owner_cancels_once_preserving_money_and_history_and_restaurant_cannot_accept(): void
    {
        Event::fake([OrderUpdated::class]);
        $this->freezeTime();
        $order = $this->order();
        Sanctum::actingAs($order->user);
        $url = '/api/orders/'.$order->id.'/cancel';
        $this->postJson($url)->assertOk()
            ->assertJsonPath('order.status', 'cancelled')
            ->assertJsonPath('order.cancellation_reason', 'El cliente canceló el pedido.');
        $order->refresh();
        $cancelledAt = $order->cancelled_at->toDateTimeString();
        $this->assertNull($order->accepted_at);
        $this->assertNull($order->delivered_at);
        foreach (['subtotal' => '3.00', 'delivery_fee' => '2.00', 'courier_fee' => '1.50',
            'platform_fee' => '0.50', 'tip_amount' => '1.00', 'total' => '6.00'] as $key => $value) {
            $this->assertSame($value, $order->{$key});
        }
        $this->travel(1)->minutes();
        $this->postJson($url)->assertOk();
        $this->assertSame($cancelledAt, $order->fresh()->cancelled_at->toDateTimeString());
        $this->getJson('/api/orders?scope=history')->assertJsonPath('orders.0.id', $order->id);
        $this->getJson('/api/orders')->assertJsonCount(0, 'orders');
        Sanctum::actingAs($order->restaurant->user);
        $this->patchJson('/api/restaurant/orders/'.$order->id, ['status' => 'accepted'])
            ->assertUnprocessable();
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
    }

    public function test_restaurant_acceptance_wins_before_customer_cancellation(): void
    {
        Event::fake([OrderUpdated::class]);
        $order = $this->order();
        Sanctum::actingAs($order->restaurant->user);
        $this->patchJson('/api/restaurant/orders/'.$order->id, ['status' => 'accepted'])->assertOk();
        $acceptedAt = $order->fresh()->accepted_at->toDateTimeString();
        Sanctum::actingAs($order->user);
        $this->postJson('/api/orders/'.$order->id.'/cancel')->assertStatus(409)
            ->assertJsonPath('order.status', 'accepted');
        $this->assertSame($acceptedAt, $order->fresh()->accepted_at->toDateTimeString());
        $this->assertNull($order->fresh()->cancelled_at);
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
    }

    public function test_other_accounts_and_non_pending_orders_cannot_be_cancelled(): void
    {
        Event::fake([OrderUpdated::class]);
        $order = $this->order();
        $this->postJson('/api/orders/'.$order->id.'/cancel')->assertUnauthorized();
        foreach ([User::factory()->create(), $order->restaurant->user, User::factory()->courier()->create()] as $other) {
            Sanctum::actingAs($other);
            $this->postJson('/api/orders/'.$order->id.'/cancel')->assertNotFound();
        }
        $this->assertSame(OrderStatus::Pending, $order->fresh()->status);
        foreach (['accepted', 'preparing', 'ready', 'picked_up', 'delivered', 'rejected'] as $status) {
            $closed = $this->order($status);
            Sanctum::actingAs($closed->user);
            $this->postJson('/api/orders/'.$closed->id.'/cancel')->assertStatus(409);
            $this->assertSame($status, $closed->fresh()->status->value);
        }
        Event::assertNotDispatched(OrderUpdated::class);
    }

    public function test_cancellation_at_deadline_preserves_expiration_reason_and_legacy_pending_can_cancel(): void
    {
        Event::fake([OrderUpdated::class]);
        $this->freezeTime();
        $order = $this->order();
        $order->acceptance_expires_at = now();
        $order->save();
        Sanctum::actingAs($order->user);
        $this->postJson('/api/orders/'.$order->id.'/cancel')->assertOk()
            ->assertJsonPath('order.cancellation_reason', 'El restaurante no respondió a tiempo.');
        $this->postJson('/api/orders/'.$order->id.'/cancel')->assertOk();
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
        $legacy = $this->order();
        $legacy->acceptance_expires_at = null;
        $legacy->save();
        Sanctum::actingAs($legacy->user);
        $this->postJson('/api/orders/'.$legacy->id.'/cancel')->assertOk()
            ->assertJsonPath('order.cancellation_reason', 'El cliente canceló el pedido.');
    }
}
