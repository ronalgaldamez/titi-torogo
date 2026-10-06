<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OrderRecoveryTest extends TestCase
{
    use RefreshDatabase;

    public function test_missing_order_is_not_created_and_late_submission_is_blocked(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);
        $key = 'missing-order-attempt';

        for ($attempt = 0; $attempt < 2; $attempt++) {
            $this->postJson('/api/orders/recover', ['idempotency_key' => $key])
                ->assertOk()->assertExactJson(['order' => null]);
        }

        $this->assertDatabaseCount('orders', 0);
        $this->assertDatabaseCount('abandoned_order_attempts', 1);
        $this->postJson('/api/orders', [
            'idempotency_key' => $key,
            'restaurant_id' => 1,
            'address_id' => 1,
            'items' => [['product_id' => 1, 'quantity' => 1]],
        ])->assertStatus(409);
        $this->assertDatabaseCount('orders', 0);
    }

    public function test_existing_order_is_recovered_only_by_its_owner_without_resending(): void
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => $other->id,
            'name' => 'Restaurante cerrado',
            'address' => 'Centro',
            'phone' => '70000000',
            'latitude' => 14.1,
            'longitude' => -89.1,
            'is_open' => false,
        ]);
        $key = 'existing-order-attempt';
        $order = DB::table('orders')->insertGetId([
            'user_id' => $owner->id,
            'restaurant_id' => $restaurant,
            'delivery_address' => 'Dirección privada',
            'delivery_latitude' => 14.2,
            'delivery_longitude' => -89.2,
            'subtotal' => '5.25',
            'delivery_fee' => '2.00',
            'courier_fee' => '1.50',
            'platform_fee' => '0.50',
            'total' => '7.25',
            'idempotency_key' => $key,
        ]);

        Sanctum::actingAs($owner);
        for ($attempt = 0; $attempt < 2; $attempt++) {
            $this->postJson('/api/orders/recover', ['idempotency_key' => $key])
                ->assertOk()->assertJsonPath('order.id', $order)
                ->assertJsonPath('order.total', '7.25')
                ->assertJsonPath('order.delivery.address', 'Dirección privada');
        }
        $this->assertDatabaseCount('abandoned_order_attempts', 0);

        Sanctum::actingAs($other);
        $this->postJson('/api/orders/recover', ['idempotency_key' => $key])
            ->assertOk()->assertExactJson(['order' => null]);
        $this->assertDatabaseCount('orders', 1);
    }

    public function test_recovery_requires_authentication_and_a_valid_key(): void
    {
        $this->postJson('/api/orders/recover', ['idempotency_key' => 'valid-attempt'])
            ->assertUnauthorized();
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/orders/recover', ['idempotency_key' => 'short'])
            ->assertUnprocessable();
        $this->assertDatabaseCount('abandoned_order_attempts', 0);
    }
}
