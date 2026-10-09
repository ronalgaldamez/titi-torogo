<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Events\CouriersUpdated;
use App\Events\OrderUpdated;
use App\Http\Controllers\Admin\OrderController as AdminOrders;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderStateTest extends TestCase
{
    use DatabaseMigrations;

    private User $restaurantUser;
    private User $courier;
    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();
        $this->restaurantUser = User::factory()->restaurant()->create();
        $this->courier = User::factory()->courier()->create();
        $client = User::factory()->create();
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => $this->restaurantUser->id,
            'name' => 'Restaurante', 'address' => 'Centro', 'phone' => '70000000',
            'latitude' => 14.1, 'longitude' => -89.1, 'is_active' => true,
        ]);
        $id = DB::table('orders')->insertGetId([
            'user_id' => $client->id, 'restaurant_id' => $restaurant,
            'delivery_address' => 'Casa', 'delivery_latitude' => 14.2,
            'delivery_longitude' => -89.2, 'subtotal' => '4.00',
            'delivery_fee' => '2.00', 'courier_fee' => '1.50',
            'platform_fee' => '0.50', 'total' => '6.00',
            'idempotency_key' => 'state-test-order',
        ]);
        $this->order = Order::findOrFail($id);
        Event::fake([OrderUpdated::class, CouriersUpdated::class]);
    }

    public function test_full_flow_and_repeated_steps_preserve_times_and_notifications(): void
    {
        Sanctum::actingAs($this->restaurantUser);
        foreach (['accepted', 'preparing', 'ready'] as $status) {
            $url = "/api/restaurant/orders/{$this->order->id}";
            $this->patchJson($url, ['status' => $status])->assertOk();
            $timestamps = $this->order->fresh()->only(['accepted_at', 'ready_at', 'updated_at']);
            Event::fake([OrderUpdated::class, CouriersUpdated::class]);
            $this->travel(1)->minutes();
            $this->patchJson($url, ['status' => $status])->assertOk();
            $this->assertEquals($timestamps, $this->order->fresh()->only(array_keys($timestamps)));
            Event::assertNotDispatched(OrderUpdated::class);
            Event::assertNotDispatched(CouriersUpdated::class);
        }

        Sanctum::actingAs($this->courier);
        $this->postJson("/api/courier/orders/{$this->order->id}/take")->assertOk()
            ->assertJsonStructure(['order' => ['items', 'restaurant', 'delivery', 'courier']]);
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
        Event::fake([OrderUpdated::class, CouriersUpdated::class]);
        $this->postJson("/api/courier/orders/{$this->order->id}/take")->assertOk();
        Event::assertNotDispatched(OrderUpdated::class);

        foreach (['picked_up', 'delivered'] as $status) {
            $url = "/api/courier/orders/{$this->order->id}";
            $this->patchJson($url, ['status' => $status])->assertOk();
            $timestamps = $this->order->fresh()->only(['picked_up_at', 'delivered_at', 'updated_at']);
            Event::fake([OrderUpdated::class, CouriersUpdated::class]);
            $this->travel(1)->minutes();
            $this->patchJson($url, ['status' => $status])->assertOk();
            $this->assertEquals($timestamps, $this->order->fresh()->only(array_keys($timestamps)));
            Event::assertNotDispatched(OrderUpdated::class);
        }
    }

    public function test_invalid_steps_and_other_profiles_cannot_modify_the_order(): void
    {
        Sanctum::actingAs($this->restaurantUser);
        foreach (['ready', 'delivered', 'invalid'] as $status) {
            $this->patchJson("/api/restaurant/orders/{$this->order->id}", ['status' => $status])
                ->assertUnprocessable();
        }
        Sanctum::actingAs(User::factory()->create());
        $this->patchJson("/api/restaurant/orders/{$this->order->id}", ['status' => 'accepted'])
            ->assertForbidden();
        $this->postJson("/api/courier/orders/{$this->order->id}/take")->assertForbidden();

        $this->order->status = OrderStatus::Ready;
        $this->order->courier_id = $this->courier->id;
        $this->order->save();
        Sanctum::actingAs(User::factory()->courier()->create());
        $this->patchJson("/api/courier/orders/{$this->order->id}", ['status' => 'picked_up'])
            ->assertNotFound();
        $this->postJson("/api/courier/orders/{$this->order->id}/take")->assertUnprocessable();
        Sanctum::actingAs($this->courier);
        foreach (['accepted', 'delivered'] as $status) {
            $this->patchJson("/api/courier/orders/{$this->order->id}", ['status' => $status])
                ->assertUnprocessable();
        }
        $this->assertSame(OrderStatus::Ready, $this->order->fresh()->status);
        Event::assertNotDispatched(OrderUpdated::class);
    }

    public function test_admin_uses_current_state_instead_of_stale_route_model(): void
    {
        $stale = $this->order;
        // La copia del controlador sigue pendiente, pero el pedido ya fue entregado.
        DB::table('orders')->where('id', $stale->id)->update(['status' => 'delivered']);
        app(AdminOrders::class)->cancel($stale);
        $this->assertNotNull(session('error'));
        $this->assertSame(OrderStatus::Delivered, $stale->fresh()->status);
        Event::assertNotDispatched(OrderUpdated::class);
    }

    public function test_cancelled_order_cannot_be_reassigned_released_or_picked_up(): void
    {
        $this->order->status = OrderStatus::Ready;
        $this->order->courier_id = $this->courier->id;
        $this->order->save();
        $stale = $this->order;
        $admin = app(AdminOrders::class);
        $admin->cancel($stale);
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
        Event::fake([OrderUpdated::class, CouriersUpdated::class]);
        $admin->cancel($stale);
        $admin->releaseCourier($stale);
        $request = Request::create('/', 'POST', ['courier_id' => User::factory()->courier()->create()->id]);
        $admin->assignCourier($request, $stale);
        Sanctum::actingAs($this->courier);
        $this->patchJson("/api/courier/orders/{$stale->id}", ['status' => 'picked_up'])
            ->assertUnprocessable();
        $this->assertSame(OrderStatus::Cancelled, $stale->fresh()->status);
        $this->assertSame($this->courier->id, $stale->fresh()->courier_id);
        Event::assertNotDispatched(OrderUpdated::class);
    }

    public function test_reassignment_revokes_old_courier_and_release_is_repeatable(): void
    {
        $this->order->status = OrderStatus::Ready;
        $this->order->courier_id = $this->courier->id;
        $this->order->save();
        $next = User::factory()->courier()->create();
        $admin = User::factory()->admin()->create();
        $this->actingAs($admin);
        $url = "/admin/pedidos/{$this->order->id}";
        $this->post($url.'/motorizado', ['courier_id' => $next->id])->assertSessionHas('status');
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
        Event::fake([OrderUpdated::class, CouriersUpdated::class]);
        $this->post($url.'/motorizado', ['courier_id' => $next->id])->assertSessionHas('status');
        Event::assertNotDispatched(OrderUpdated::class);
        Sanctum::actingAs($this->courier);
        $this->patchJson("/api/courier/orders/{$this->order->id}", ['status' => 'picked_up'])
            ->assertNotFound();
        $this->actingAs($admin, 'web');
        $this->post($url.'/liberar')->assertSessionHas('status');
        Event::fake([OrderUpdated::class, CouriersUpdated::class]);
        $this->post($url.'/liberar')->assertSessionHas('status');
        $this->assertNull($this->order->fresh()->courier_id);
        Event::assertNotDispatched(OrderUpdated::class);
    }

    public function test_reassigning_an_order_on_the_way_notifies_couriers_without_private_data(): void
    {
        $this->order->status = OrderStatus::PickedUp;
        $this->order->tip_amount = '1.00';
        $this->order->total = '7.00';
        $this->order->courier_id = $this->courier->id;
        $this->order->save();
        $next = User::factory()->courier()->create();
        $this->actingAs(User::factory()->admin()->create(), 'web');
        $this->post("/admin/pedidos/{$this->order->id}/motorizado", ['courier_id' => $next->id])
            ->assertSessionHas('status');
        Event::assertDispatched(CouriersUpdated::class,
            fn ($event) => $event->broadcastWith() === ['order_id' => $this->order->id]);

        Sanctum::actingAs($this->courier);
        $this->getJson('/api/courier/orders')->assertOk()->assertExactJson(['orders' => []]);
        $this->patchJson("/api/courier/orders/{$this->order->id}", ['status' => 'delivered'])
            ->assertNotFound();
        Sanctum::actingAs($next);
        $this->getJson('/api/courier/orders')->assertOk()
            ->assertJsonCount(1, 'orders')->assertJsonPath('orders.0.id', $this->order->id)
            ->assertJsonPath('orders.0.tip_amount', '1.00');
        $this->patchJson("/api/courier/orders/{$this->order->id}", ['status' => 'delivered'])->assertOk();
        $this->getJson('/api/courier/summary')->assertOk()->assertJsonPath('earnings', '2.50');
        Sanctum::actingAs($this->courier);
        $this->getJson('/api/courier/summary')->assertOk()->assertJsonPath('earnings', '0.00');
    }
}
