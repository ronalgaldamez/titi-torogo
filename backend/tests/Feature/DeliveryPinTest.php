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

class DeliveryPinTest extends TestCase
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
            'platform_fee' => '0.50', 'total' => '6.00', 'idempotency_key' => 'delivery-pin-test',
        ]));
        $this->order->refresh();
        Event::fake();
    }

    public function test_pin_is_encrypted_unique_per_step_and_visible_only_to_its_customer(): void
    {
        $pin = $this->order->delivery_pin;
        $this->assertMatchesRegularExpression('/^[0-9]{6}$/', $pin);
        $this->assertNotSame($this->order->pickup_pin, $pin);
        $this->assertNotSame($pin, DB::table('orders')->value('delivery_pin'));
        $this->assertArrayNotHasKey('delivery_pin', $this->order->toArray());
        $this->assertArrayNotHasKey('delivery_pin', (new OrderUpdated($this->order))->broadcastWith());

        $url = '/api/orders/'.$this->order->id;
        $this->order->status = OrderStatus::Pending;
        $this->order->save();
        Sanctum::actingAs($this->client);
        $this->getJson($url)->assertOk()->assertJsonPath('order.delivery_pin', $pin);
        Sanctum::actingAs(User::factory()->create());
        $this->getJson($url)->assertNotFound();

        $this->order->status = OrderStatus::PickedUp;
        $this->order->save();
        Sanctum::actingAs($this->client);
        $this->getJson($url)->assertOk()->assertJsonPath('order.delivery_pin', $pin);
        Sanctum::actingAs($this->courier);
        $this->getJson('/api/courier/orders')->assertOk()
            ->assertJsonMissingPath('orders.0.delivery_pin')->assertJsonPath('orders.0.delivery_pin_required', true);
        Sanctum::actingAs($this->owner);
        $this->getJson('/api/restaurant/orders')->assertOk()->assertJsonCount(1, 'orders')
            ->assertJsonMissingPath('orders.0.delivery_pin');
    }

    public function test_assigned_courier_needs_pin_after_pickup_and_retries_preserve_delivery(): void
    {
        $this->freezeTime();
        $url = '/api/courier/orders/'.$this->order->id;
        $correct = ['status' => 'delivered', 'delivery_pin' => $this->order->delivery_pin];
        Sanctum::actingAs($this->courier);
        $this->patchJson($url, $correct)->assertUnprocessable();

        $this->order->status = OrderStatus::PickedUp;
        $this->order->save();
        Sanctum::actingAs(User::factory()->courier()->create());
        $this->patchJson($url, $correct)->assertNotFound();
        Sanctum::actingAs($this->courier);
        $this->patchJson($url, ['status' => 'delivered'])->assertUnprocessable();
        for ($attempt = 0; $attempt < 4; $attempt++) {
            $this->patchJson($url, ['status' => 'delivered', 'delivery_pin' => $this->order->pickup_pin])
                ->assertUnprocessable();
        }
        $this->patchJson($url, $correct)->assertStatus(429)->assertHeader('Retry-After');
        $this->assertSame(OrderStatus::PickedUp, $this->order->fresh()->status);
        Event::assertNotDispatched(OrderUpdated::class);

        $this->travel(301)->seconds();
        $this->patchJson($url, $correct)->assertOk()->assertJsonMissingPath('order.delivery_pin');
        $time = $this->order->fresh()->delivered_at;
        $this->assertNotNull($time);
        $this->travel(1)->minutes();
        $this->patchJson($url, ['status' => 'delivered'])->assertOk()
            ->assertJsonPath('order.total', '6.00')->assertJsonPath('order.delivery.address', 'Casa');
        $this->assertEquals($time, $this->order->fresh()->delivered_at);
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
    }

    public function test_restaurant_owner_sees_the_delivery_pin_only_as_the_buyer(): void
    {
        $this->order->user_id = $this->owner->id;
        $this->order->save();
        $pin = $this->order->delivery_pin;
        Sanctum::actingAs($this->owner);

        $this->getJson('/api/orders')->assertOk()->assertJsonPath('orders.0.delivery_pin', $pin);
        $this->getJson('/api/orders/'.$this->order->id)->assertOk()->assertJsonPath('order.delivery_pin', $pin);
        $this->getJson('/api/restaurant/orders')->assertOk()
            ->assertJsonPath('orders.0.id', $this->order->id)
            ->assertJsonMissingPath('orders.0.delivery_pin');
    }

    public function test_a_courier_cannot_be_assigned_their_own_order(): void
    {
        $this->order->user_id = $this->courier->id;
        $this->order->courier_id = null;
        $this->order->save();
        $id = $this->order->id;
        $nearby = '/api/courier/orders/available?latitude=14.1&longitude=-89.1';
        $assign = "/admin/pedidos/{$id}/motorizado";
        $other = User::factory()->courier()->create();

        Sanctum::actingAs($this->courier);
        $this->getJson($nearby)->assertOk()->assertJsonCount(0, 'orders');
        $this->postJson("/api/courier/orders/{$id}/take")->assertUnprocessable()->assertJsonValidationErrors('order');

        Sanctum::actingAs($other);
        $this->getJson($nearby)->assertOk()->assertJsonPath('orders.0.id', $id)->assertJsonMissingPath('orders.0.delivery_pin');

        $this->actingAs(User::factory()->admin()->create(), 'web');
        $this->get("/admin/pedidos/{$id}")->assertOk()
            ->assertViewHas('couriers', fn ($couriers) => $couriers->pluck('id')->all() === [$other->id]);
        $this->post($assign, ['courier_id' => $this->courier->id])->assertSessionHas('error');
        $this->assertNull($this->order->fresh()->courier_id);
        $this->post($assign, ['courier_id' => $other->id])->assertSessionHas('status');
        $this->assertSame($other->id, $this->order->fresh()->courier_id);
    }

    public function test_a_legacy_self_assignment_does_not_reveal_the_pin(): void
    {
        $this->order->user_id = $this->courier->id;
        $this->order->status = OrderStatus::PickedUp;
        $this->order->save();
        Sanctum::actingAs($this->courier);

        $this->getJson('/api/orders/'.$this->order->id)->assertOk()->assertJsonMissingPath('order.delivery_pin');
        $this->getJson('/api/courier/orders')->assertOk()
            ->assertJsonMissingPath('orders.0.delivery_pin')->assertJsonPath('orders.0.delivery_pin_required', true);
    }

    public function test_only_admin_can_close_verified_delivery_and_first_intervention_is_retained(): void
    {
        $url = '/admin/pedidos/'.$this->order->id.'/verificar-entrega';
        $reason = 'Cliente sin acceso al PIN confirmó la recepción por teléfono.';
        $input = ['delivery_verification_reason' => $reason];

        $this->actingAs($this->courier, 'web')->post($url, $input)->assertForbidden();
        $admin = User::factory()->admin()->create();
        $this->actingAs($admin, 'web')->post($url, $input)->assertSessionHas('error');

        $this->order->status = OrderStatus::PickedUp;
        $this->order->save();
        $details = '/admin/pedidos/'.$this->order->id;
        $this->get($details)->assertOk()->assertSee('Autorizar cierre de entrega');
        $this->post($url)->assertSessionHasErrors('delivery_verification_reason');
        $this->post($url, $input)->assertSessionHas('status');
        $this->travel(1)->minutes();
        $this->actingAs(User::factory()->admin()->create(), 'web')
            ->post($url, ['delivery_verification_reason' => 'Otro motivo'])->assertSessionHas('status');

        $closed = $this->order->fresh();
        $this->assertSame(OrderStatus::Delivered, $closed->status);
        $this->assertSame($admin->id, (int) $closed->delivery_verified_by);
        $this->assertSame($reason, $closed->delivery_verification_reason);
        $this->assertSame('6.00', $closed->total);
        $this->assertNotNull($closed->delivered_at);
        $this->get($details)->assertOk()->assertSee($reason)->assertDontSee('Autorizar cierre de entrega');
        Event::assertDispatchedTimes(OrderUpdated::class, 1);
    }
}
