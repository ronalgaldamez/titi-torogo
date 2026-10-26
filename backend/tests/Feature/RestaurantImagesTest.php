<?php

namespace Tests\Feature;

use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class RestaurantImagesTest extends TestCase
{
    use DatabaseMigrations;

    private function local(User $owner, string $name = 'Baruk'): Restaurant
    {
        $id = DB::table('restaurants')->insertGetId([
            'user_id' => $owner->id, 'name' => $name, 'address' => 'Centro',
            'phone' => '70000000',
            'latitude' => 14.1, 'longitude' => -89.1, 'prep_time_minutes' => 25,
            'is_open' => true,
        ]);

        return Restaurant::findOrFail($id);
    }

    private function storage()
    {
        $disk = Storage::fake('s3');
        $disk->buildTemporaryUrlsUsing(fn ($path, $expiration, $options) => 'https://example.test/'.$path.'?signature=test');

        return $disk;
    }

    public function test_images_are_isolated_replaced_and_keep_the_directory_after_renaming(): void
    {
        $disk = $this->storage();
        $owner = User::factory()->restaurant()->create();
        $local = $this->local($owner);
        $other = $this->local(User::factory()->restaurant()->create(), 'Otro');
        Sanctum::actingAs($owner);
        $response = $this->post('/api/restaurant/images', [
            'logo' => UploadedFile::fake()->image('logo.png'),
            'cover' => UploadedFile::fake()->image('portada.jpg'),
            'restaurant_id' => $other->id,
            'media_directory' => 'negocios/otro',
        ], ['Accept' => 'application/json'])->assertOk();
        $local->refresh();
        $prefix = 'negocios/baruk-'.$local->id;
        $this->assertSame($prefix, $local->media_directory);
        $this->assertStringStartsWith($prefix.'/logo/', $local->logo_path);
        $this->assertStringStartsWith($prefix.'/portada/', $local->cover_path);
        $disk->assertExists([$local->logo_path, $local->cover_path]);
        $this->assertNull($other->refresh()->logo_path);
        $response->assertJsonPath('restaurant.logo_url', 'https://example.test/'.$local->logo_path.'?signature=test');
        $response->assertJsonPath('restaurant.cover_url', 'https://example.test/'.$local->cover_path.'?signature=test');
        $oldLogo = $local->logo_path;
        $oldCover = $local->cover_path;
        $local->name = 'Nuevo nombre';
        $local->save();
        // Cada petición real resuelve un usuario nuevo; Sanctum::actingAs conserva la instancia entre llamadas del test.
        Sanctum::actingAs($owner->fresh());
        $this->post('/api/restaurant/images', ['logo' => UploadedFile::fake()->image('nuevo.png')],
            ['Accept' => 'application/json'])->assertOk();
        $local->refresh();
        $this->assertSame($prefix, $local->media_directory);
        $this->assertSame($oldCover, $local->cover_path);
        $disk->assertMissing($oldLogo);
        $disk->assertExists([$local->logo_path, $oldCover]);
        Sanctum::actingAs($owner->fresh());
        $this->getJson('/api/restaurant/status')->assertOk()->assertJsonPath('restaurant.name', 'Nuevo nombre');
        $this->getJson('/api/restaurants/'.$local->id)->assertOk()
            ->assertJsonPath('restaurant.cover_url', 'https://example.test/'.$oldCover.'?signature=test');
    }

    public function test_invalid_files_do_not_replace_existing_images(): void
    {
        $disk = $this->storage();
        $owner = User::factory()->restaurant()->create();
        $local = $this->local($owner);
        $local->logo_path = 'negocios/anterior/logo/real.png';
        $local->save();
        $disk->put($local->logo_path, 'original');
        Sanctum::actingAs($owner);
        foreach ([
            [],
            ['logo' => UploadedFile::fake()->createWithContent('logo.svg', '<svg xmlns="http://www.w3.org/2000/svg"></svg>')],
            ['cover' => UploadedFile::fake()->image('grande.jpg')->size(5121)],
            ['logo_path' => 'otra/ruta.png'],
        ] as $payload) {
            $this->post('/api/restaurant/images', $payload, ['Accept' => 'application/json'])->assertUnprocessable();
        }
        $this->assertSame('negocios/anterior/logo/real.png', $local->refresh()->logo_path);
        $disk->assertExists($local->logo_path);
        $this->assertCount(1, $disk->allFiles());
    }

    public function test_storage_failure_rolls_back_paths_and_cleans_partial_uploads(): void
    {
        $owner = User::factory()->restaurant()->create();
        $local = $this->local($owner);
        Sanctum::actingAs($owner);
        $disk = \Mockery::mock(\Illuminate\Filesystem\FilesystemAdapter::class);
        $disk->shouldReceive('putFile')->once()->ordered()->andReturn('negocios/baruk-'.$local->id.'/logo/new.png');
        $disk->shouldReceive('putFile')->once()->ordered()->andReturn(false);
        $disk->shouldReceive('delete')->once()->with('negocios/baruk-'.$local->id.'/logo/new.png')->andReturn(true);
        Storage::set('s3', $disk);
        $this->post('/api/restaurant/images', [
            'logo' => UploadedFile::fake()->image('logo.png'),
            'cover' => UploadedFile::fake()->image('portada.jpg'),
        ], ['Accept' => 'application/json'])->assertStatus(503);
        $this->assertNull($local->refresh()->logo_path);
        $this->assertNull($local->cover_path);
        $this->assertNull($local->media_directory);
    }

    public function test_only_a_restaurant_account_can_upload(): void
    {
        $this->postJson('/api/restaurant/images')->assertUnauthorized();
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/restaurant/images')->assertForbidden();
    }
}
