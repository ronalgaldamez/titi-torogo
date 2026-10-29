<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProductEditorTest extends TestCase
{
    use DatabaseMigrations;

    private function local(User $owner): Restaurant
    {
        return Restaurant::findOrFail(DB::table('restaurants')->insertGetId([
            'user_id' => $owner->id, 'name' => 'Baruk', 'address' => 'Centro',
            'phone' => '70000000', 'latitude' => 14.1, 'longitude' => -89.1,
            'is_open' => true, 'is_active' => true,
        ]));
    }

    private function offer(): array
    {
        return ['name' => 'Burrito momia', 'price' => '8.75', 'offer_enabled' => true,
            'sale_price' => '7.50', 'offer_starts_at' => now()->toIso8601String(),
            'offer_ends_at' => now()->addHour()->toIso8601String()];
    }

    public function test_photo_and_offer_save_together_replace_safely_and_keep_directory(): void
    {
        $this->freezeTime();
        $disk = Storage::fake('s3');
        $disk->buildTemporaryUrlsUsing(fn ($path) => 'https://example.test/'.$path);
        $owner = User::factory()->restaurant()->create();
        $local = $this->local($owner);
        Sanctum::actingAs($owner);
        $created = $this->post('/api/restaurant/menu/products', $this->offer() + [
            'image' => UploadedFile::fake()->image('plato.jpg'),
        ], ['Accept' => 'application/json'])->assertCreated()
            ->assertJsonPath('product.price', '7.50')->assertJsonPath('product.regular_price', '8.75');
        $product = Product::findOrFail($created->json('product.id'));
        $old = $product->image_path;
        $prefix = 'negocios/baruk-'.$local->id.'/platos/'.$product->id.'/';
        $this->assertStringStartsWith($prefix, $old);
        $disk->assertExists($old);
        $this->assertSame(now()->timestamp, $product->offer_starts_at->timestamp);
        $this->assertSame(now()->addHour()->timestamp, $product->offer_ends_at->timestamp);
        $this->assertSame('8.75', $product->effectivePrice(now()->subSecond()));
        $local->name = 'Nuevo nombre';
        $local->save();
        Sanctum::actingAs($owner->fresh());
        $this->post('/api/restaurant/menu/products/'.$product->id, $this->offer() + [
            '_method' => 'PUT', 'image' => UploadedFile::fake()->image('nuevo.png'),
        ], ['Accept' => 'application/json'])->assertOk();
        $this->assertStringStartsWith($prefix, $product->refresh()->image_path);
        $disk->assertMissing($old);
        $disk->assertExists($product->image_path);
        $this->travel(1)->hours();
        $this->assertSame('8.75', $product->effectivePrice());
        $this->putJson('/api/restaurant/menu/products/'.$product->id,
            ['name' => 'Burrito momia', 'price' => '8.75', 'offer_enabled' => false])
            ->assertOk()->assertJsonPath('product.sale_price', null)->assertJsonPath('product.offer_enabled', false);
    }

    public function test_invalid_offer_or_image_cannot_change_the_product_and_other_owner_has_no_access(): void
    {
        $owner = User::factory()->restaurant()->create();
        $local = $this->local($owner);
        $product = $local->products()->create(['name' => 'Original', 'price' => '8.75']);
        Sanctum::actingAs($owner);
        foreach ([['sale_price' => '9.00'], ['sale_price' => '-1.00'], ['sale_price' => '1.005'],
            ['offer_ends_at' => now()->subDay()->toIso8601String()]] as $invalid) {
            $this->putJson('/api/restaurant/menu/products/'.$product->id, array_replace($this->offer(), $invalid))
                ->assertUnprocessable();
        }
        $this->post('/api/restaurant/menu/products/'.$product->id, $this->offer() + [
            '_method' => 'PUT', 'image' => UploadedFile::fake()->createWithContent('bad.svg', '<svg/>'),
        ], ['Accept' => 'application/json'])->assertUnprocessable();
        $this->assertSame('Original', $product->refresh()->name);
        $this->assertNull($product->image_path);
        $other = User::factory()->restaurant()->create();
        $this->local($other);
        Sanctum::actingAs($other);
        $this->putJson('/api/restaurant/menu/products/'.$product->id, $this->offer())->assertNotFound();
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/restaurant/menu/products', $this->offer())->assertForbidden();
    }

    public function test_failed_storage_rolls_back_new_product_and_existing_details(): void
    {
        $owner = User::factory()->restaurant()->create();
        $local = $this->local($owner);
        $product = $local->products()->create(['name' => 'Original', 'price' => '8.75', 'image_path' => 'old/photo.jpg']);
        Sanctum::actingAs($owner);
        $disk = \Mockery::mock(\Illuminate\Filesystem\FilesystemAdapter::class);
        $disk->shouldReceive('putFile')->twice()->andReturn(false);
        Storage::set('s3', $disk);
        foreach (['/api/restaurant/menu/products', '/api/restaurant/menu/products/'.$product->id] as $url) {
            $this->post($url, $this->offer() + [
                '_method' => $url === '/api/restaurant/menu/products' ? 'POST' : 'PUT',
                'image' => UploadedFile::fake()->image('plato.jpg'),
            ], ['Accept' => 'application/json'])->assertStatus(503);
        }
        $this->assertDatabaseCount('products', 1);
        $this->assertSame('Original', $product->refresh()->name);
        $this->assertSame('old/photo.jpg', $product->image_path);
        $this->assertFalse($product->offer_enabled);
        $this->assertNull($local->refresh()->media_directory);
    }
}
