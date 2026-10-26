<?php

namespace Tests\Feature;

use App\Http\Resources\ProductResource;
use App\Models\Restaurant;
use App\Models\User;
use Database\Seeders\BarukMenuSeeder;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class BarukMenuTest extends TestCase
{
    use DatabaseMigrations;

    private function restaurant(User $owner): Restaurant
    {
        $id = DB::table('restaurants')->insertGetId([
            'user_id' => $owner->id, 'name' => 'Baruk the picnic house',
            'phone' => '70000000', 'address' => 'Tejutla',
            'latitude' => 14.1, 'longitude' => -89.1,
            'media_directory' => 'negocios/original-'.$owner->id,
            'logo_path' => 'logo-real.png', 'cover_path' => 'portada-real.jpg',
            'prep_time_minutes' => 25,
        ]);

        return Restaurant::findOrFail($id);
    }

    public function test_adds_only_baruks_real_dishes_and_photos_without_overwriting_later_edits(): void
    {
        $disk = Storage::fake('s3');
        $disk->buildTemporaryUrlsUsing(fn ($path, $expiration, $options) => 'https://example.test/'.$path.'?signature=test');
        $owner = User::factory()->restaurant()->create(['email' => 'sombreron@torogo.local']);
        $restaurant = $this->restaurant($owner);
        $other = $this->restaurant(User::factory()->restaurant()->create());
        $old = DB::table('products')->insertGetId([
            'restaurant_id' => $restaurant->id, 'name' => 'Pupusa de prueba', 'price' => '1.00',
        ]);
        $otherProduct = DB::table('products')->insertGetId([
            'restaurant_id' => $other->id, 'name' => 'Pupusa de prueba', 'price' => '1.00',
        ]);
        $this->seed(BarukMenuSeeder::class);
        $expected = [
            ['Burrito momia', '8.75', 'burrito-momia.jpg'],
            ['Rib eye', '17.00', 'rib-eye.jpg'],
            ['Taquiza Pastora', '13.50', 'taquiza-pastora.jpg'],
        ];
        $this->assertSame(3, $restaurant->products()->count());
        $this->assertSame(1, $other->products()->count());
        $this->assertSoftDeleted('products', ['id' => $old]);
        $this->assertDatabaseHas('products', ['id' => $otherProduct, 'deleted_at' => null]);
        $this->assertSame(1, $restaurant->menuCategories()->where('name', 'Especialidades')->count());
        foreach ($expected as [$name, $price, $file]) {
            $product = $restaurant->products()->where('name', $name)->firstOrFail();
            $this->assertSame($price, $product->price);
            $this->assertTrue($product->is_available);
            $this->assertSame($restaurant->media_directory.'/platos/'.$product->id.'/'.$file, $product->image_path);
            $this->assertSame(hash_file('sha256', database_path('data/baruk/'.$file)), hash('sha256', $disk->get($product->image_path)));
            $resource = (new ProductResource($product))->resolve(Request::create('/api/restaurants/'.$restaurant->id));
            $this->assertSame('https://example.test/'.$product->image_path.'?signature=test', $resource['image_url']);
        }
        $product = $restaurant->products()->where('name', 'Rib eye')->firstOrFail();
        $product->price = '18.00';
        $product->is_available = false;
        $product->save();
        $this->seed(BarukMenuSeeder::class);
        $this->assertSame(3, $restaurant->products()->count());
        $this->assertCount(3, $disk->allFiles());
        $this->assertSame('18.00', $product->refresh()->price);
        $this->assertFalse($product->is_available);
        $this->assertSame('logo-real.png', $restaurant->refresh()->logo_path);
        $this->assertSame('portada-real.jpg', $restaurant->cover_path);
        $this->assertSame('negocios/original-'.$owner->id, $restaurant->media_directory);
    }

    public function test_failed_upload_rolls_back_new_dishes_and_cleans_uploaded_photos(): void
    {
        $restaurant = $this->restaurant(User::factory()->restaurant()->create(['email' => 'sombreron@torogo.local']));
        $disk = \Mockery::mock(\Illuminate\Filesystem\FilesystemAdapter::class);
        $disk->shouldReceive('exists')->twice()->andReturn(false);
        $disk->shouldReceive('put')->once()->ordered()->andReturn(true);
        $disk->shouldReceive('put')->once()->ordered()->andReturn(false);
        $disk->shouldReceive('delete')->once()->andReturn(true);
        Storage::set('s3', $disk);
        try {
            (new BarukMenuSeeder)->run();
            $this->fail('La carga incompleta debe fallar.');
        } catch (\RuntimeException $error) {
            $this->assertStringContainsString('No se pudo subir la foto', $error->getMessage());
        }
        $this->assertSame(0, $restaurant->products()->count());
        $this->assertSame(0, $restaurant->menuCategories()->count());
    }
}
