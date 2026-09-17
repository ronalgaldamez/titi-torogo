<?php

namespace Database\Seeders;

use App\Enums\UserRole;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Los restaurantes REALES de Tejutla, Chalatenango.
 *
 * Coordenadas reales, no inventadas: el Home filtra por la zona de reparto,
 * asi que un restaurante fuera de la zona simplemente no aparece nunca.
 * Estas 11 estan todas dentro del poligono de database/data/.
 *
 * 7 estan en Mall del Sol (km 51 carretera Troncal del Norte) y comparten
 * el mismo punto: es un centro comercial, y asi se ve en un mapa real.
 *
 * Es idempotente: busca por email y actualiza en vez de duplicar.
 */
class RestaurantSeeder extends Seeder
{
    /**
     * Contrasena de las cuentas de desarrollo (SOLO LOCAL).
     */
    private const DEV_PASSWORD = 'torogo123';

    /**
     * Mall del Sol: km 51 carretera Troncal del Norte, Tejutla.
     * Coordenada real tomada de Google Maps.
     */
    private const MALL_DEL_SOL_LAT = 14.101203787387021;

    private const MALL_DEL_SOL_LNG = -89.15061654556241;

    private const MALL_DEL_SOL_ADDRESS = 'Mall del Sol, km 51 carretera Troncal del Norte, Tejutla';

    public function run(): void
    {
        foreach ($this->restaurants() as $data) {
            $user = User::firstOrNew(['email' => $data['email']]);
            $user->name = $data['name'];
            $user->password = self::DEV_PASSWORD; // el cast 'hashed' lo encripta
            $user->role = UserRole::Restaurant;   // asignacion directa: 'role' no es fillable
            $user->email_verified_at = now();
            $user->save();

            // Igual que 'role': 'user_id' no es fillable, se asigna explicito.
            $restaurant = Restaurant::firstOrNew(['user_id' => $user->id]);
            $restaurant->user_id = $user->id;

            $restaurant->name = $data['name'];
            $restaurant->description = $data['description'] ?? null;
            $restaurant->address = $data['address'];
            $restaurant->phone = $data['phone'];
            $restaurant->latitude = $data['latitude'];
            $restaurant->longitude = $data['longitude'];
            $restaurant->prep_time_minutes = $data['prep_time_minutes'];

            // null = "usá la tarifa de mi zona" (ver DeliveryZone). El dinero
            // del envio lo define la plataforma porque el motorizado es de la
            // plataforma: el restaurante no controla la distancia ni el costo.
            // Un restaurante puede poner 0.00 para ofrecer "envio gratis".
            $restaurant->delivery_fee = $data['delivery_fee'];

            // is_active / is_open / is_busy no son fillable: asignacion directa.
            // The Coffee Cup queda CERRADO a proposito, para que el filtro del
            // Home tenga un caso real que dejar fuera.
            $restaurant->is_active = true;
            $restaurant->is_open = $data['is_open'];
            $restaurant->is_busy = false;

            $restaurant->save();
        }
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function restaurants(): array
    {
        return [
            // ---------------- Mall del Sol (mismo punto) ----------------
            [
                // Cuenta demo del UserSeeder: queda como duena de un local real.
                'email' => 'restaurante@torogo.local',
                'name' => 'Los Tres Cerditos',
                'description' => 'Carnes, parrilladas y tipicos.',
                'address' => self::MALL_DEL_SOL_ADDRESS,
                'phone' => '+503 2300 1001',
                'latitude' => self::MALL_DEL_SOL_LAT,
                'longitude' => self::MALL_DEL_SOL_LNG,
                'prep_time_minutes' => 30,
                'delivery_fee' => null,
                'is_open' => true,
            ],
            [
                'email' => 'subway@torogo.local',
                'name' => 'Subway',
                'description' => 'Sandwiches submarinos hechos al momento.',
                'address' => self::MALL_DEL_SOL_ADDRESS,
                'phone' => '+503 2300 1002',
                'latitude' => self::MALL_DEL_SOL_LAT,
                'longitude' => self::MALL_DEL_SOL_LNG,
                'prep_time_minutes' => 15,
                'delivery_fee' => null,
                'is_open' => true,
            ],
            [
                'email' => 'zocalo@torogo.local',
                'name' => 'El Zocalo',
                'description' => 'Comida tipica salvadorena.',
                'address' => self::MALL_DEL_SOL_ADDRESS,
                'phone' => '+503 2300 1003',
                'latitude' => self::MALL_DEL_SOL_LAT,
                'longitude' => self::MALL_DEL_SOL_LNG,
                'prep_time_minutes' => 25,
                'delivery_fee' => null,
                'is_open' => true,
            ],
            [
                'email' => 'fusheng@torogo.local',
                'name' => 'Fu Sheng',
                'description' => 'Comida china.',
                'address' => self::MALL_DEL_SOL_ADDRESS,
                'phone' => '+503 2300 1004',
                'latitude' => self::MALL_DEL_SOL_LAT,
                'longitude' => self::MALL_DEL_SOL_LNG,
                'prep_time_minutes' => 30,
                'delivery_fee' => null,
                'is_open' => true,
            ],
            [
                'email' => 'urbanpizza@torogo.local',
                'name' => 'Urban Pizza',
                'description' => 'Pizza al estilo urbano.',
                'address' => self::MALL_DEL_SOL_ADDRESS,
                'phone' => '+503 2300 1005',
                'latitude' => self::MALL_DEL_SOL_LAT,
                'longitude' => self::MALL_DEL_SOL_LNG,
                'prep_time_minutes' => 25,
                'delivery_fee' => null,
                'is_open' => true,
            ],
            [
                'email' => 'stlouis@torogo.local',
                'name' => 'St. Louis Steak House',
                'description' => 'Cortes de carne a la parrilla.',
                'address' => self::MALL_DEL_SOL_ADDRESS,
                'phone' => '+503 2300 1006',
                'latitude' => self::MALL_DEL_SOL_LAT,
                'longitude' => self::MALL_DEL_SOL_LNG,
                'prep_time_minutes' => 35,
                'delivery_fee' => null,
                'is_open' => true,
            ],
            [
                'email' => 'coffeecup@torogo.local',
                'name' => 'The Coffee Cup',
                'description' => 'Cafe, reposteria y desayunos.',
                'address' => self::MALL_DEL_SOL_ADDRESS,
                'phone' => '+503 2300 1007',
                'latitude' => self::MALL_DEL_SOL_LAT,
                'longitude' => self::MALL_DEL_SOL_LNG,
                'prep_time_minutes' => 15,
                'delivery_fee' => null,
                // CERRADO a proposito: caso real para probar el filtro.
                'is_open' => false,
            ],

            // ------------- Resto de la zona de Tejutla -------------
            [
                'email' => 'buenavista@torogo.local',
                'name' => 'Buena Vista Restaurante Cafe',
                'description' => 'Restaurante y cafeteria.',
                'address' => 'Tejutla, Chalatenango',
                'phone' => '+503 2300 1008',
                'latitude' => 14.091578362725258,
                'longitude' => -89.14654055652022,
                'prep_time_minutes' => 20,
                'delivery_fee' => null,
                'is_open' => true,
            ],
            [
                'email' => 'pinulito@torogo.local',
                'name' => 'Pollo Pinulito El Coyolito Nuevo',
                'description' => 'Pollo frito y ala brasa.',
                'address' => 'El Coyolito, Tejutla, Chalatenango',
                'phone' => '+503 2300 1009',
                'latitude' => 14.090810937308126,
                'longitude' => -89.1460564502686,
                'prep_time_minutes' => 25,
                'delivery_fee' => null,
                'is_open' => true,
            ],
            [
                'email' => 'lasvegas@torogo.local',
                'name' => 'Restaurante Las Vegas',
                'description' => 'Comida tipica y antojitos.',
                'address' => 'Tejutla, Chalatenango',
                'phone' => '+503 2300 1010',
                'latitude' => 14.08348291269134,
                'longitude' => -89.14305386065153,
                'prep_time_minutes' => 30,
                'delivery_fee' => null,
                'is_open' => true,
            ],
            [
                'email' => 'sombreron@torogo.local',
                'name' => 'El Sombreron Guanaco',
                'description' => 'Comida guanaca y parrilladas.',
                'address' => 'Tejutla, Chalatenango',
                'phone' => '+503 2300 1011',
                'latitude' => 14.081704798815732,
                'longitude' => -89.14083786485189,
                'prep_time_minutes' => 25,
                'delivery_fee' => null,
                'is_open' => true,
            ],
        ];
    }
}
