<?php

namespace Tests\Feature;

use App\Models\Restaurant;
use App\Models\RestaurantCategory;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Http\UploadedFile;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RestaurantCategoriesTest extends TestCase
{
    use DatabaseMigrations;

    public function test_admin_upload_preserves_replaces_and_removes_optional_icons(): void
    {
        Storage::fake('public');
        $this->actingAs(User::factory()->admin()->create());
        $png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j1ioAAAAASUVORK5CYII=');
        $data = ['name' => 'Cuca', 'sort_order' => 8, 'is_active' => true];
        $this->post('/admin/categorias', $data + ['icon' => UploadedFile::fake()->createWithContent('cuca.png', $png)])
            ->assertSessionHasNoErrors()->assertRedirect('/admin/categorias');
        $category = RestaurantCategory::where('name', 'Cuca')->firstOrFail();
        $firstPath = $category->icon_path;
        Storage::disk('public')->assertExists($firstPath);
        $this->get('/api/category-icons/'.$category->id)->assertOk()->assertHeader('Content-Type', 'image/png');
        $url = '/admin/categorias/'.$category->id;
        $this->put($url, $data)->assertSessionHasNoErrors();
        $this->assertSame($firstPath, $category->fresh()->icon_path);
        $this->put($url, $data + ['icon' => UploadedFile::fake()->createWithContent('nuevo.png', $png)])
            ->assertSessionHasNoErrors();
        $secondPath = $category->fresh()->icon_path;
        $this->assertNotSame($firstPath, $secondPath);
        Storage::disk('public')->assertMissing($firstPath);
        Storage::disk('public')->assertExists($secondPath);
        $this->put($url, $data + ['icon' => UploadedFile::fake()->createWithContent('script.svg', '<svg xmlns="http://www.w3.org/2000/svg"></svg>')])
            ->assertSessionHasErrors('icon');
        $this->assertSame($secondPath, $category->fresh()->icon_path);
        $this->put($url, $data + ['remove_icon' => true])->assertSessionHasNoErrors();
        $this->assertNull($category->fresh()->icon_path);
        Storage::disk('public')->assertMissing($secondPath);
        $this->assertSame('restaurant', $category->fresh()->icon_key);
        $this->get('/api/category-icons/'.$category->id)->assertNotFound();
    }

    private function restaurant(): Restaurant
    {
        $id = DB::table('restaurants')->insertGetId([
            'user_id' => User::factory()->restaurant()->create()->id,
            'name' => 'Local', 'address' => 'Centro', 'phone' => '70000000',
            'latitude' => 14.1, 'longitude' => -89.1, 'is_open' => true, 'is_active' => true,
        ]);

        return Restaurant::findOrFail($id);
    }

    public function test_only_admin_manages_names_order_and_activation_without_duplicate_names(): void
    {
        $this->withoutVite();
        $this->get('/admin/categorias')->assertRedirect('/admin/login');
        $this->actingAs(User::factory()->create())->post('/admin/categorias', [])->assertForbidden();
        $this->actingAs(User::factory()->admin()->create());
        $data = ['name' => '  Mariscos  ', 'sort_order' => 20, 'is_active' => true];
        $this->post('/admin/categorias', $data)->assertRedirect('/admin/categorias');
        $category = RestaurantCategory::where('name', 'Mariscos')->firstOrFail();
        $this->get('/admin/categorias')->assertOk()->assertSee('Mariscos');
        $this->get('/admin/categorias/'.$category->id.'/editar')->assertOk();
        $this->post('/admin/categorias', array_replace($data, ['name' => 'MARISCOS']))
            ->assertSessionHasErrors('normalized_name');
        $this->put('/admin/categorias/'.$category->id, [
            'name' => 'Mariscos del día', 'sort_order' => 1, 'is_active' => false,
        ])->assertRedirect('/admin/categorias');
        $this->assertFalse($category->fresh()->is_active);
        $this->assertSame(1, $category->fresh()->sort_order);
    }

    public function test_owner_selects_only_active_categories_for_own_local_without_touching_menu(): void
    {
        $local = $this->restaurant();
        $other = $this->restaurant();
        $ids = RestaurantCategory::orderBy('id')->pluck('id');
        $menu = $local->menuCategories()->create(['name' => 'Platos de la casa', 'sort_order' => 0]);
        $this->putJson('/api/restaurant/categories', ['category_ids' => []])->assertUnauthorized();
        Sanctum::actingAs(User::factory()->create());
        $this->getJson('/api/restaurant/categories')->assertForbidden();
        Sanctum::actingAs($local->user);
        $this->putJson('/api/restaurant/categories', ['category_ids' => [$ids[0], $ids[1]], 'restaurant_id' => $other->id])
            ->assertOk()->assertJsonCount(2, 'restaurant.food_categories');
        $this->assertSame(0, $other->categories()->count());
        $this->getJson('/api/restaurant/categories')->assertOk()->assertJsonCount(2, 'selected_ids');
        DB::table('restaurant_categories')->where('id', $ids[2])->update(['is_active' => false]);
        foreach ([[$ids[0], $ids[0]], [$ids[2]], [999999]] as $invalid) {
            $this->putJson('/api/restaurant/categories', ['category_ids' => $invalid])->assertUnprocessable();
            $this->assertSame(2, $local->categories()->count());
        }
        $this->putJson('/api/restaurant/categories', [])->assertUnprocessable();
        $this->putJson('/api/restaurant/categories', ['category_ids' => []])->assertOk();
        $this->assertSame(0, $local->categories()->count());
        $this->assertDatabaseHas('menu_categories', ['id' => $menu->id, 'name' => 'Platos de la casa']);
    }

    public function test_public_catalog_uses_admin_order_hides_inactive_and_keeps_uncategorized_restaurants(): void
    {
        $local = $this->restaurant();
        $other = $this->restaurant();
        $categories = RestaurantCategory::orderBy('id')->get();
        $local->categories()->sync([$categories[0]->id, $categories[1]->id]);
        DB::table('restaurant_categories')->where('id', $categories[0]->id)->update(['is_active' => false]);
        DB::table('restaurant_categories')->where('id', $categories[1]->id)->update(['sort_order' => 0]);
        DB::table('delivery_zones')->insert([
            'name' => 'Zona', 'polygon' => json_encode(['type' => 'Polygon',
                'coordinates' => [[[-90, 14], [-89, 14], [-89, 15], [-90, 15], [-90, 14]]]]),
            'courier_fee' => '1.50', 'platform_fee' => '0.50', 'is_active' => true,
        ]);
        $response = $this->getJson('/api/restaurants?latitude=14.2&longitude=-89.2')->assertOk()
            ->assertJsonCount(2, 'restaurants')->assertJsonCount(4, 'food_categories')
            ->assertJsonPath('food_categories.0.id', $categories[1]->id);
        $rows = collect($response->json('restaurants'))->keyBy('id');
        $this->assertSame([$categories[1]->id], array_column($rows[$local->id]['food_categories'], 'id'));
        $this->assertSame([], $rows[$other->id]['food_categories']);
        $this->getJson('/api/restaurants/'.$local->id)->assertOk()->assertJsonCount(1, 'restaurant.food_categories');
        Sanctum::actingAs($local->user);
        $this->getJson('/api/restaurant/categories')->assertOk()->assertJsonCount(4, 'categories')
            ->assertJsonCount(1, 'selected_ids');
    }
}
