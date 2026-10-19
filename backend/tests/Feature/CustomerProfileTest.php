<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CustomerProfileTest extends TestCase
{
    use DatabaseMigrations;

    public function test_customer_updates_only_own_name_and_phone_and_me_keeps_the_changes(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create(['name' => 'Otra persona']);
        $password = $user->password;
        Sanctum::actingAs($user);
        $this->patchJson('/api/me', ['name' => '  Ronald Galdámez  ', 'phone' => '+503 7000-1234'])
            ->assertOk()->assertJsonPath('id', $user->id)
            ->assertJsonPath('name', 'Ronald Galdámez')
            ->assertJsonPath('phone', '70001234')
            ->assertJsonPath('email', $user->email)
            ->assertJsonMissingPath('password');
        $this->getJson('/api/me')->assertOk()->assertJsonPath('phone', '70001234');
        $user->refresh();
        $this->assertSame($password, $user->password);
        $this->assertSame(UserRole::Client, $user->role);
        $this->assertSame('Otra persona', $other->fresh()->name);
        $this->patchJson('/api/me', ['name' => 'Ronald', 'phone' => null])
            ->assertOk()->assertJsonPath('phone', null);
    }

    public function test_invalid_inputs_do_not_partially_save_the_profile(): void
    {
        $user = User::factory()->create(['name' => 'Original', 'phone' => '70001234']);
        Sanctum::actingAs($user);
        foreach (['123', 'abcdefgh', '12345678', '+15551234567', ['70001234'], 70001234] as $phone) {
            $this->patchJson('/api/me', ['name' => 'Nuevo', 'phone' => $phone])
                ->assertUnprocessable()->assertJsonValidationErrors('phone');
        }
        foreach ([' ', 'A', str_repeat('a', 256), ['Nombre']] as $name) {
            $this->patchJson('/api/me', ['name' => $name, 'phone' => '70001234'])
                ->assertUnprocessable()->assertJsonValidationErrors('name');
        }
        $this->patchJson('/api/me', ['name' => 'Nuevo'])
            ->assertUnprocessable()->assertJsonValidationErrors('phone');
        $this->assertSame('Original', $user->fresh()->name);
        $this->assertSame('70001234', $user->fresh()->phone);
    }

    public function test_email_permissions_password_and_other_accounts_cannot_be_modified(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        Sanctum::actingAs($user);
        $this->patchJson('/api/me', [
            'name' => 'Nuevo', 'phone' => '70001234', 'id' => $other->id,
            'email' => 'otra@torogo.local', 'role' => 'admin', 'password' => 'changed-password',
        ])->assertUnprocessable()->assertJsonValidationErrors(['id', 'email', 'role', 'password']);
        $this->assertSame($user->name, $user->fresh()->name);
        $this->assertSame($user->email, $user->fresh()->email);
        $this->assertSame(UserRole::Client, $user->fresh()->role);
        $this->assertFalse(Hash::check('changed-password', $user->fresh()->password));
        $this->assertSame($other->name, $other->fresh()->name);
        $this->patchJson('/api/me', [
            'name' => 'Nuevo', 'phone' => '70001234', 'is_active' => false, 'is_available' => true,
        ])->assertOk();
        $this->assertTrue((bool) $user->fresh()->is_active);
        $this->assertFalse((bool) $user->fresh()->is_available);
    }

    public function test_profile_update_requires_authenticated_customer(): void
    {
        $data = ['name' => 'Nuevo', 'phone' => '70001234'];
        $this->patchJson('/api/me', $data)->assertUnauthorized();
        foreach (['restaurant', 'courier', 'admin'] as $role) {
            $user = User::factory()->{$role}()->create();
            Sanctum::actingAs($user);
            $this->patchJson('/api/me', $data)->assertForbidden();
            $this->assertSame($user->name, $user->fresh()->name);
        }
    }
}
