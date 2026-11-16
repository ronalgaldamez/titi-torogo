<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class AdminDesignTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_keeps_authentication_fields_and_has_the_official_brand_and_themes(): void
    {
        $this->get(route('login'))->assertOk()
            ->assertSee('images/brand/torogo-dark.svg', false)
            ->assertSee('autocomplete="current-password"', false)
            ->assertSee('name="_token"', false)
            ->assertSee('data-skip-confirm', false)
            ->assertSee('value="black"', false)
            ->assertSee('value="white"', false);
    }

    public function test_all_admin_sections_render_the_shared_navigation_and_confirmation_dialog(): void
    {
        $this->actingAs(User::factory()->admin()->create());

        foreach (['dashboard', 'orders.index', 'restaurants.index', 'couriers.index', 'customers.index', 'categories.index', 'backups.index', 'settings.index', 'landing.edit', 'restaurants.create', 'couriers.create', 'categories.create'] as $route) {
            $this->get(route('admin.'.$route))->assertOk()
                ->assertSee('id="admin-sidebar"', false)
                ->assertSee('id="admin-confirmation"', false)
                ->assertSee('aria-current="page"', false)
                ->assertSee('js/admin.js', false);
        }
    }

    public function test_redesigned_admin_still_requires_an_admin_account(): void
    {
        $this->get(route('admin.dashboard'))->assertRedirect(route('login'));
        $this->actingAs(User::factory()->create())
            ->get(route('admin.dashboard'))->assertForbidden();
    }

    public function test_existing_records_keep_their_forms_and_contextual_confirmations(): void
    {
        $this->actingAs(User::factory()->admin()->create());
        $owner = User::factory()->restaurant()->create();
        $courier = User::factory()->courier()->create();
        $client = User::factory()->create();
        $restaurant = DB::table('restaurants')->insertGetId([
            'user_id' => $owner->id, 'name' => 'Local de prueba', 'address' => 'Centro',
            'phone' => '70000000', 'latitude' => 14.1, 'longitude' => -89.1,
        ]);
        $order = DB::table('orders')->insertGetId([
            'user_id' => $client->id, 'restaurant_id' => $restaurant, 'courier_id' => $courier->id,
            'status' => 'ready', 'delivery_address' => 'Casa', 'delivery_latitude' => 14.2,
            'delivery_longitude' => -89.2, 'subtotal' => '4.00', 'delivery_fee' => '2.00',
            'courier_fee' => '1.50', 'platform_fee' => '0.50', 'total' => '6.00',
            'idempotency_key' => 'admin-design-order', 'created_at' => now(), 'updated_at' => now(),
        ]);

        $this->get(route('admin.orders.show', $order))->assertOk()
            ->assertSee('¿Cancelar este pedido?')->assertSee('¿Asignar este motorizado?')->assertSee('¿Liberar este pedido?')
            ->assertSee('name="courier_id"', false);
        $this->get(route('admin.restaurants.edit', $restaurant))->assertOk()->assertSee('Cambiarás el acceso de Local de prueba');
        $this->get(route('admin.couriers.edit', $courier))->assertOk()->assertSee('¿Desactivar esta cuenta?');
        $this->get(route('admin.customers.show', $client))->assertOk()->assertSee('admin-mobile-logo');
        $this->get(route('admin.dashboard'))->assertOk()->assertSee('Local de prueba')->assertSee('$6.00');
    }
}
