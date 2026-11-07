<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\Restaurant;
use App\Models\User;
use Database\Seeders\VpsTestAccountsSeeder;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use RuntimeException;
use Tests\TestCase;

class VpsTestAccountsSeederTest extends TestCase
{
    use DatabaseMigrations;

    public function test_role_collision_rolls_back_without_changing_existing_accounts(): void
    {
        $existing = User::factory()->create(['email' => 'motorizado.pruebas@torogo.local']);
        $before = $existing->getAttributes();

        try {
            $this->seed(VpsTestAccountsSeeder::class);
            $this->fail('Debe rechazar una cuenta existente con otro rol.');
        } catch (RuntimeException $exception) {
            $this->assertStringContainsString('otro rol', $exception->getMessage());
        }

        $this->assertSame(1, User::count());
        $this->assertSame(0, Restaurant::count());
        $this->assertSame($before, $existing->refresh()->getAttributes());
    }

    public function test_creates_only_two_accounts_and_preserves_them_on_rerun(): void
    {
        $existing = User::factory()->create();
        $before = $existing->getAttributes();

        $this->seed(VpsTestAccountsSeeder::class);

        $this->assertSame(3, User::count());
        $this->assertSame(1, Restaurant::count());
        $owner = User::where('email', 'restaurante.pruebas@torogo.local')->firstOrFail();
        $courier = User::where('email', 'motorizado.pruebas@torogo.local')->firstOrFail();
        $this->assertSame(UserRole::Restaurant, $owner->role);
        $this->assertSame(UserRole::Courier, $courier->role);
        $this->assertFalse((bool) $courier->is_available);
        $this->assertFalse($owner->restaurant->is_open);
        $this->assertSame(0, $owner->restaurant->products()->count());
        $this->assertNotEmpty(password_get_info($owner->password)['algo']);
        $password = $owner->password;
        $owner->name = 'Nombre editado desde el teléfono';
        $owner->is_active = false;
        $owner->save();

        $this->seed(VpsTestAccountsSeeder::class);

        $this->assertSame(3, User::count());
        $this->assertSame(1, Restaurant::count());
        $this->assertSame($password, $owner->refresh()->password);
        $this->assertSame('Nombre editado desde el teléfono', $owner->name);
        $this->assertFalse((bool) $owner->is_active);
        $this->assertSame($before, $existing->refresh()->getAttributes());
    }
}
