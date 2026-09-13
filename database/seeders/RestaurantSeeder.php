<?php

namespace Database\Seeders;

use App\Enums\UserRole;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Restaurantes de prueba con coordenadas REALES del area metropolitana
 * de San Salvador.
 *
 * Son reales a proposito: el Home del cliente filtra por cercania, asi que
 * con coordenadas inventadas las distancias y el mapa no tendrian sentido.
 *
 * Es idempotente: busca por email y actualiza en vez de duplicar.
 */
class RestaurantSeeder extends Seeder
{
    /**
     * Contrasena de las cuentas de desarrollo (SOLO LOCAL).
     */
    private const DEV_PASSWORD = 'torogo123';

    public function run(): void
    {
        foreach ($this->restaurants() as $data) {
            $user = User::firstOrNew(['email' => $data['email']]);
            $user->name = $data['owner'];
            $user->password = self::DEV_PASSWORD; // el cast 'hashed' lo encripta
            $user->role = UserRole::Restaurant;   // asignacion directa: 'role' no es fillable
            $user->email_verified_at = now();
            $user->save();

            // Igual que con 'role': 'user_id' no es fillable, asi que se
            // asigna de forma explicita despues de encontrar o crear la fila.
            $restaurant = Restaurant::firstOrNew(['user_id' => $user->id]);
            $restaurant->user_id = $user->id;

            $restaurant->name = $data['name'];
            $restaurant->description = $data['description'];
            $restaurant->address = $data['address'];
            $restaurant->phone = $data['phone'];
            $restaurant->latitude = $data['latitude'];
            $restaurant->longitude = $data['longitude'];
            $restaurant->prep_time_minutes = $data['prep_time_minutes'];
            $restaurant->delivery_fee = $data['delivery_fee'];

            // is_active / is_open / is_busy no son fillable: asignacion directa.
            $restaurant->is_active = true;
            $restaurant->is_open = $data['is_open'];
            $restaurant->is_busy = false;

            $restaurant->save();
        }
    }

    /**
     * Un restaurante cerrado a proposito ("Sushi Zen"): asi el filtro del
     * Home tiene algo real que dejar fuera y se puede probar de verdad.
     *
     * @return array<int, array<string, mixed>>
     */
    private function restaurants(): array
    {
        return [
            [
                'email' => 'restaurante@torogo.local',
                'owner' => 'Restaurante Demo',
                'name' => 'Pupuseria El Toro',
                'description' => 'Pupusas de queso, frijol y chicharron hechas a mano.',
                'address' => 'Calle Arce, Centro Historico, San Salvador',
                'phone' => '+503 2222 1001',
                'latitude' => 13.6929,
                'longitude' => -89.2182,
                'prep_time_minutes' => 20,
                'delivery_fee' => 1.50,
                'is_open' => true,
            ],
            [
                'email' => 'pizza@torogo.local',
                'owner' => 'Pizza Nostra',
                'name' => 'Pizza Nostra',
                'description' => 'Pizza artesanal en horno de lena.',
                'address' => 'Bulevar del Hipodromo, Colonia Escalon, San Salvador',
                'phone' => '+503 2222 1002',
                'latitude' => 13.7025,
                'longitude' => -89.2444,
                'prep_time_minutes' => 35,
                'delivery_fee' => 2.00,
                'is_open' => true,
            ],
            [
                'email' => 'taqueria@torogo.local',
                'owner' => 'Taqueria El Volcan',
                'name' => 'Taqueria El Volcan',
                'description' => 'Tacos, burritos y aguas frescas.',
                'address' => 'Zona Rosa, San Benito, San Salvador',
                'phone' => '+503 2222 1003',
                'latitude' => 13.6960,
                'longitude' => -89.2450,
                'prep_time_minutes' => 25,
                'delivery_fee' => 1.75,
                'is_open' => true,
            ],
            [
                'email' => 'comedor@torogo.local',
                'owner' => 'Comedor La Ceiba',
                'name' => 'Comedor La Ceiba',
                'description' => 'Comida tipica salvadorena: sopa de pata, yuca y casamiento.',
                'address' => '1a Calle Poniente, Santa Tecla, La Libertad',
                'phone' => '+503 2222 1004',
                'latitude' => 13.6769,
                'longitude' => -89.2797,
                'prep_time_minutes' => 30,
                'delivery_fee' => 2.50,
                'is_open' => true,
            ],
            [
                'email' => 'sushi@torogo.local',
                'owner' => 'Sushi Zen',
                'name' => 'Sushi Zen',
                'description' => 'Rollos calientes y sashimi.',
                'address' => 'Boulevard Orden de Malta, Antiguo Cuscatlan, La Libertad',
                'phone' => '+503 2222 1005',
                'latitude' => 13.6745,
                'longitude' => -89.2470,
                'prep_time_minutes' => 40,
                'delivery_fee' => 3.00,
                'is_open' => false,
            ],
            [
                'email' => 'burger@torogo.local',
                'owner' => 'Burger House SV',
                'name' => 'Burger House SV',
                'description' => 'Hamburguesas a la parrilla con papas rusticas.',
                'address' => 'Calle La Mascota, San Marcos, San Salvador',
                'phone' => '+503 2222 1006',
                'latitude' => 13.6889,
                'longitude' => -89.2333,
                'prep_time_minutes' => 20,
                'delivery_fee' => 1.50,
                'is_open' => true,
            ],
        ];
    }
}
