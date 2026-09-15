<?php

namespace Database\Factories;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'remember_token' => Str::random(10),
        ];
    }

    /**
     * El atributo 'role' NO es fillable (ver App\Models\User). Si lo pusieramos
     * en definition() o dentro de un state(), Eloquent lo descartaria EN SILENCIO
     * y los tests pasarian con el perfil equivocado sin avisar. Por eso se
     * asigna de forma directa con afterMaking().
     */
    public function configure(): static
    {
        return $this->afterMaking(fn (User $user) => $user->role = UserRole::Client);
    }

    public function admin(): static
    {
        return $this->afterMaking(fn (User $user) => $user->role = UserRole::Admin);
    }

    public function restaurant(): static
    {
        return $this->afterMaking(fn (User $user) => $user->role = UserRole::Restaurant);
    }

    public function courier(): static
    {
        return $this->afterMaking(fn (User $user) => $user->role = UserRole::Courier);
    }

    /**
     * Indicate that the model's email address should be unverified.
     */
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }
}
