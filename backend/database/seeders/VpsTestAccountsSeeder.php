<?php

namespace Database\Seeders;

use App\Enums\UserRole;
use App\Enums\Vehicle;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

class VpsTestAccountsSeeder extends Seeder
{
    public function run(): void
    {
        $credentials = DB::transaction(function (): array {
            $created = [];

            foreach ([
                ['restaurante.pruebas@torogo.local', 'Restaurante de pruebas', UserRole::Restaurant],
                ['motorizado.pruebas@torogo.local', 'Motorizado de pruebas', UserRole::Courier],
            ] as [$email, $name, $role]) {
                $user = User::firstOrNew(['email' => $email]);

                if ($user->exists) {
                    if ($user->role !== $role) {
                        throw new RuntimeException("La cuenta {$email} ya existe con otro rol. No se modificó.");
                    }

                    continue;
                }

                $password = Str::password(20);
                $user->name = $name;
                $user->password = $password;
                $user->role = $role;
                $user->email_verified_at = now();
                $user->is_active = true;
                $user->is_available = false;

                if ($role === UserRole::Courier) {
                    $user->vehicle = Vehicle::Motorcycle->value;
                }

                $user->save();

                if ($role === UserRole::Restaurant) {
                    $restaurant = new Restaurant;
                    $restaurant->user_id = $user->id;
                    $restaurant->name = $name;
                    $restaurant->description = 'Local de pruebas de ToroGo.';
                    $restaurant->address = 'Mall del Sol, Tejutla, Chalatenango';
                    $restaurant->phone = '';
                    $restaurant->latitude = 14.101203787387021;
                    $restaurant->longitude = -89.15061654556241;
                    $restaurant->prep_time_minutes = 30;
                    $restaurant->delivery_fee = null;
                    $restaurant->is_active = true;
                    $restaurant->is_open = false;
                    $restaurant->is_busy = false;
                    $restaurant->save();
                }

                $created[] = "{$email} | Contraseña: {$password}";
            }

            return $created;
        });

        foreach ($credentials as $credential) {
            $this->command?->line($credential);
        }

        $this->command?->info('Listo. Las cuentas existentes se conservaron. Guardá las contraseñas nuevas: no se vuelven a mostrar.');
    }
}
