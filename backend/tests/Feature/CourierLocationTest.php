<?php

namespace Tests\Feature;

use App\Events\OrderUpdated;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CourierLocationTest extends TestCase
{
    use DatabaseMigrations;

    private function delivery(): Order
    {
        config(['cache.default' => 'array']);
        Cache::flush();
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => User::factory()->restaurant()->create()->id,
            'name' => 'Local', 'address' => 'Centro', 'phone' => '70000000',
            'latitude' => 14.1, 'longitude' => -89.1,
        ]);
        $id = DB::table('orders')->insertGetId([
            'user_id' => User::factory()->create()->id,
            'courier_id' => User::factory()->courier()->create()->id,
            'restaurant_id' => $restaurant, 'status' => 'ready',
            'delivery_address' => 'Casa', 'delivery_latitude' => 14.2, 'delivery_longitude' => -89.2,
            'subtotal' => '3.00', 'delivery_fee' => '2.00', 'courier_fee' => '1.50',
            'platform_fee' => '0.50', 'total' => '5.00', 'idempotency_key' => fake()->uuid(),
        ]);

        return Order::findOrFail($id);
    }

    private function point(): array
    {
        return ['latitude' => 14.15, 'longitude' => -89.15,
            'accuracy' => 12, 'captured_at' => now()->toISOString()];
    }

    public function test_only_current_courier_writes_and_customer_reads_without_broadcasting_coordinates(): void
    {
        Event::fake([OrderUpdated::class]);
        $order = $this->delivery();
        $this->getJson("/api/orders/{$order->id}/location")->assertUnauthorized();
        Sanctum::actingAs($order->courier);
        $this->patchJson("/api/courier/orders/{$order->id}/location", $this->point())
            ->assertOk()->assertJsonPath('accepted', true);
        Event::assertNotDispatched(OrderUpdated::class);
        Sanctum::actingAs(User::factory()->courier()->create());
        $this->patchJson("/api/courier/orders/{$order->id}/location", $this->point())->assertNotFound();
        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/orders/{$order->id}/location")->assertNotFound();
        $this->patchJson("/api/courier/orders/{$order->id}/location", $this->point())->assertForbidden();
        Sanctum::actingAs($order->restaurant->user);
        $this->getJson("/api/orders/{$order->id}/location")->assertNotFound();
        Sanctum::actingAs($order->user);
        $this->getJson("/api/orders/{$order->id}/location")->assertOk()
            ->assertJsonPath('location.latitude', 14.15)->assertHeader('Cache-Control', 'no-store, private');
        $this->getJson("/api/orders/{$order->id}")->assertOk()->assertJsonMissingPath('order.location');
    }

    public function test_rejects_bad_old_or_out_of_order_samples_and_expires_last_position(): void
    {
        $this->freezeTime();
        $order = $this->delivery();
        Sanctum::actingAs($order->courier);
        $endpoint = "/api/courier/orders/{$order->id}/location";
        foreach ([['latitude' => 91], ['longitude' => -181], ['accuracy' => 101],
            ['captured_at' => now()->subSeconds(31)->toISOString()],
            ['captured_at' => now()->addSeconds(11)->toISOString()]] as $bad) {
            $this->patchJson($endpoint, array_replace($this->point(), $bad))->assertUnprocessable();
        }
        $this->patchJson($endpoint, $this->point())->assertOk()->assertJsonPath('accepted', true);
        $this->patchJson($endpoint, array_replace($this->point(), [
            'latitude' => 14.3, 'captured_at' => now()->subSecond()->toISOString(),
        ]))->assertOk()->assertJsonPath('accepted', false);
        Sanctum::actingAs($order->user);
        $this->getJson("/api/orders/{$order->id}/location")->assertOk()->assertJsonPath('location.latitude', 14.15);
        $this->travel(121)->seconds();
        $this->getJson("/api/orders/{$order->id}/location")->assertOk()->assertJsonPath('location', null);
    }

    public function test_reassignment_and_closed_orders_do_not_expose_old_courier_position(): void
    {
        $order = $this->delivery();
        $old = $order->courier;
        Sanctum::actingAs($old);
        $this->patchJson("/api/courier/orders/{$order->id}/location", $this->point())->assertOk();
        $new = User::factory()->courier()->create();
        DB::table('orders')->where('id', $order->id)->update(['courier_id' => $new->id]);
        $this->patchJson("/api/courier/orders/{$order->id}/location", $this->point())->assertNotFound();
        Sanctum::actingAs($order->user);
        $this->getJson("/api/orders/{$order->id}/location")->assertOk()->assertJsonPath('courier_id', $new->id)
            ->assertJsonPath('location', null);
        Sanctum::actingAs($new);
        $this->patchJson("/api/courier/orders/{$order->id}/location", $this->point())->assertOk();
        foreach (['delivered', 'cancelled', 'rejected'] as $status) {
            DB::table('orders')->where('id', $order->id)->update(['status' => $status]);
            $this->patchJson("/api/courier/orders/{$order->id}/location", $this->point())->assertStatus(409);
            Sanctum::actingAs($order->user);
            $this->getJson("/api/orders/{$order->id}/location")->assertOk()->assertJsonPath('location', null);
            Sanctum::actingAs($new);
        }
    }
}
