<?php

namespace Tests\Feature;

use App\Models\Restaurant;
use App\Models\User;
use Database\Seeders\MenuSeeder;
use Database\Seeders\RestaurantSeeder;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class BarukNameTest extends TestCase
{
    use DatabaseMigrations;

    public function test_rename_preserves_images_credentials_and_other_restaurants(): void
    {
        $owner = User::factory()->restaurant()->create([
            'email' => 'sombreron@torogo.local', 'name' => 'El Sombreron Guanaco',
        ]);
        $other = User::factory()->restaurant()->create();
        foreach ([$owner, $other] as $user) {
            DB::table('restaurants')->insert([
                'user_id' => $user->id, 'name' => 'El Sombreron Guanaco',
                'address' => 'Tejutla', 'phone' => '70000000',
                'latitude' => 14.1, 'longitude' => -89.1,
                'logo_path' => 'negocios/local-'.$user->id.'/logo/real.png',
                'cover_path' => 'negocios/local-'.$user->id.'/portada/real.jpg',
                'media_directory' => 'negocios/local-'.$user->id,
                'prep_time_minutes' => 25, 'is_open' => true,
            ]);
        }
        $before = (array) DB::table('restaurants')->where('user_id', $owner->id)->first();
        $password = $owner->password;
        $migration = require database_path('migrations/2026_10_25_130000_rename_sombreron_to_baruk_the_picnic_house.php');
        $migration->up();
        $migration->up();
        $after = (array) DB::table('restaurants')->where('user_id', $owner->id)->first();
        $this->assertSame('Baruk the picnic house', $after['name']);
        unset($before['name'], $before['updated_at'], $after['name'], $after['updated_at']);
        $this->assertSame($before, $after);
        $this->assertSame($password, $owner->refresh()->password);
        $this->assertSame('sombreron@torogo.local', $owner->email);
        $this->assertSame('Baruk the picnic house', $owner->name);
        $this->assertDatabaseHas('restaurants', ['user_id' => $other->id, 'name' => 'El Sombreron Guanaco']);
    }

    public function test_seeders_use_the_new_name_and_still_create_its_demo_menu(): void
    {
        $this->seed([RestaurantSeeder::class, MenuSeeder::class]);
        $restaurant = Restaurant::whereHas('user', fn ($query) => $query->where('email', 'sombreron@torogo.local'))->firstOrFail();
        $this->assertSame('Baruk the picnic house', $restaurant->name);
        $this->assertTrue($restaurant->products()->exists());
    }
}
