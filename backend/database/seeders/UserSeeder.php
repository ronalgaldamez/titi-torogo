<?php

namespace Database\Seeders;

use App\Enums\UserRole;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Crea una cuenta de prueba por cada perfil de ToroGo.
 *
 * Es idempotente: si volves a correrlo, actualiza las existentes
 * en vez de duplicarlas (busca por email).
 */
class UserSeeder extends Seeder
{
    /**
     * Contrasena de las cuentas de desarrollo.
     *
     * SOLO PARA LOCAL. En produccion el administrador define cada clave
     * y se cambia al primer ingreso.
     */
    private const DEV_PASSWORD = 'torogo123';

    public function run(): void
    {
        $accounts = [
            [
                'name' => 'Ronald (Admin)',
                'email' => 'admin@torogo.local',
                'role' => UserRole::Admin,
            ],
            [
                'name' => 'Restaurante Demo',
                'email' => 'restaurante@torogo.local',
                'role' => UserRole::Restaurant,
            ],
            [
                'name' => 'Motorizado Demo',
                'email' => 'motorizado@torogo.local',
                'role' => UserRole::Courier,
            ],
            [
                'name' => 'Cliente Demo',
                'email' => 'cliente@torogo.local',
                'role' => UserRole::Client,
            ],
        ];

        foreach ($accounts as $account) {
            $user = User::firstOrNew(['email' => $account['email']]);

            // Asignacion DIRECTA a proposito (no mass assignment).
            // 'role' no esta en $fillable justamente para que nadie pueda
            // escalar privilegios mandando role=admin desde la API.
            $user->name = $account['name'];
            $user->password = self::DEV_PASSWORD; // el cast 'hashed' lo encripta
            $user->role = $account['role'];
            $user->email_verified_at = now();

            $user->save();
        }
    }
}
