<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class CustomerRegistrationTest extends TestCase
{
    use DatabaseMigrations;

    public function test_registration_creates_only_a_customer_and_returns_a_working_session(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'Nuevo cliente', 'email' => 'nuevo@example.com',
            'password' => 'clave1234', 'password_confirmation' => 'clave1234',
            'role' => 'admin', 'is_available' => true,
        ])->assertCreated()->assertJsonPath('user.role', 'client')->assertJsonMissingPath('user.password');
        $user = User::where('email', 'nuevo@example.com')->firstOrFail();
        $this->assertSame(UserRole::Client, $user->role);
        $this->assertTrue(Hash::check('clave1234', $user->password));
        $this->assertFalse((bool) $user->is_available);
        $this->withToken($response->json('token'))->getJson('/api/me')
            ->assertOk()->assertJsonPath('id', $user->id);
    }

    public function test_invalid_registration_never_creates_an_account(): void
    {
        $this->postJson('/api/register', [
            'name' => '', 'email' => 'incorrecto', 'password' => 'corta',
            'password_confirmation' => 'distinta',
        ])->assertUnprocessable()->assertJsonValidationErrors(['name', 'email', 'password']);
        $this->assertDatabaseCount('users', 0);
    }

    public function test_existing_email_cannot_be_registered_again_or_change_its_password(): void
    {
        $existing = User::factory()->create(['email' => 'existente@example.com']);
        $originalPassword = $existing->password;
        $this->postJson('/api/register', [
            'name' => 'Otro nombre', 'email' => $existing->email,
            'password' => 'clave1234', 'password_confirmation' => 'clave1234',
        ])->assertUnprocessable()->assertJsonValidationErrors('email');
        $this->assertDatabaseCount('users', 1);
        $this->assertSame($originalPassword, $existing->fresh()->password);
        $this->assertSame(0, $existing->tokens()->count());
    }
}
