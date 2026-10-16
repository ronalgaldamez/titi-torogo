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

class PendingOrderExpirationTest extends TestCase
{
    use DatabaseMigrations;

    private function pending(?string $deadline, string $status = 'pending'): Order
    {
        $owner = User::factory()->restaurant()->create();
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => $owner->id, 'name' => 'Local', 'address' => 'Centro',
            'phone' => '70000000', 'latitude' => 14.1, 'longitude' => -89.1,
        ]);
        $id = DB::table('orders')->insertGetId([
            'user_id' => User::factory()->create()->id, 'restaurant_id' => $restaurant,
            'status' => $status, 'delivery_address' => 'Casa',
            'delivery_latitude' => 14.2, 'delivery_longitude' => -89.2,
            'subtotal' => '3.00', 'delivery_fee' => '2.00', 'courier_fee' => '1.50',
            'platform_fee' => '0.50', 'tip_amount' => '1.00', 'total' => '6.00',
            'idempotency_key' => fake()->uuid(), 'created_at' => now()->subMinutes(5),
            'acceptance_expires_at' => $deadline,
        ]);

        return Order::findOrFail($id);
    }

    public function test_scheduler_expires_only_due_pending_orders_once_without_changing_money(): void
    {
        Event::fake([OrderUpdated::class]);
        $this->freezeTime();
        $due = $this->pending(now()->toDateTimeString());
        $future = $this->pending(now()->addSecond()->toDateTimeString());
        $legacy = $this->pending(null);
        $accepted = $this->pending(now()->subMinute()->toDateTimeString(), 'accepted');
        $this->artisan('orders:expire-pending')->assertSuccessful();
        $due->refresh();
        $this->assertSame(OrderStatus::Cancelled, $due->status);
        $this->assertSame('El restaurante no respondió a tiempo.', $due->cancellation_reason);
        $this->assertNotNull($due->cancelled_at);
        $this->assertNull($due->delivered_at);
        $this->assertSame('6.00', $due->total);
        $this->assertSame('1.00', $due->tip_amount);
        $this->assertSame(OrderStatus::Pending, $future->fresh()->status);
        $this->assertSame(OrderStatus::Pending, $legacy->fresh()->status);
        $this->assertSame(OrderStatus::Accepted, $accepted->fresh()->status);
        $cancelledAt = $due->cancelled_at->toDateTimeString();
        $this->artisan('orders:expire-pending')->assertSuccessful();
        $this->assertSame($cancelledAt, $due->fresh()->cancelled_at->toDateTimeString());
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
    }

    public function test_acceptance_at_deadline_commits_cancellation_even_without_scheduler(): void
    {
        Event::fake([OrderUpdated::class]);
        $this->freezeTime();
        $order = $this->pending(now()->toDateTimeString());
        Sanctum::actingAs($order->restaurant->user);
        $this->patchJson('/api/restaurant/orders/'.$order->id, ['status' => 'accepted'])
            ->assertStatus(409)->assertJsonPath('order.status', 'cancelled');
        $this->assertSame(OrderStatus::Cancelled, $order->fresh()->status);
        $this->assertNull($order->fresh()->accepted_at);
        $this->patchJson('/api/restaurant/orders/'.$order->id, ['status' => 'accepted'])
            ->assertUnprocessable();
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
    }

    public function test_acceptance_before_deadline_survives_later_scheduler_runs(): void
    {
        Event::fake([OrderUpdated::class]);
        $this->freezeTime();
        $order = $this->pending(now()->addSecond()->toDateTimeString());
        Sanctum::actingAs($order->restaurant->user);
        $this->patchJson('/api/restaurant/orders/'.$order->id, ['status' => 'accepted'])->assertOk();
        $this->travel(10)->minutes();
        $this->artisan('orders:expire-pending')->assertSuccessful();
        $this->assertSame(OrderStatus::Accepted, $order->fresh()->status);
        $this->assertNull($order->fresh()->cancellation_reason);
    }

    public function test_other_restaurant_cannot_trigger_expiration_of_someone_elses_order(): void
    {
        Event::fake([OrderUpdated::class]);
        $this->freezeTime();
        $order = $this->pending(now()->toDateTimeString());
        $other = $this->pending(null);
        Sanctum::actingAs($other->restaurant->user);
        $this->patchJson('/api/restaurant/orders/'.$order->id, ['status' => 'accepted'])
            ->assertNotFound();
        $this->assertSame(OrderStatus::Pending, $order->fresh()->status);
        Event::assertNotDispatched(OrderUpdated::class);
    }
}
