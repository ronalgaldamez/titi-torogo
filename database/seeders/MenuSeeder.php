<?php

namespace Database\Seeders;

use App\Models\MenuCategory;
use App\Models\Product;
use App\Models\Restaurant;
use Illuminate\Database\Seeder;

/**
 * Menus de prueba para los restaurantes de Tejutla.
 *
 * Los menus se comparten por TIPO de comida (los 4 de comida tipica usan el
 * mismo "tipicos") para no repetir cientos de lineas de platos identicos.
 * Cada restaurante igual recibe sus propias filas: son suyos y puede
 * editarlos sin afectar a nadie.
 *
 * Es idempotente: busca por nombre y actualiza en vez de duplicar.
 */
class MenuSeeder extends Seeder
{
    /**
     * Que menu le toca a cada restaurante.
     *
     * @var array<string, string>
     */
    private const MENU_BY_RESTAURANT = [
        'Los Tres Cerditos' => 'tipicos',
        'El Zocalo' => 'tipicos',
        'Restaurante Las Vegas' => 'tipicos',
        'El Sombreron Guanaco' => 'tipicos',
        'Buena Vista Restaurante Cafe' => 'cafe',
        'The Coffee Cup' => 'cafe',
        'Subway' => 'sandwiches',
        'Fu Sheng' => 'china',
        'Urban Pizza' => 'pizza',
        'St. Louis Steak House' => 'carnes',
        'Pollo Pinulito El Coyolito Nuevo' => 'pollo',
    ];

    public function run(): void
    {
        $menus = $this->menus();

        foreach (Restaurant::all() as $restaurant) {
            $menuKey = self::MENU_BY_RESTAURANT[$restaurant->name] ?? null;

            if ($menuKey === null || ! isset($menus[$menuKey])) {
                continue;
            }

            $this->seedMenu($restaurant, $menus[$menuKey]);
        }
    }

    /**
     * @param  array<string, array<int, array{0: string, 1: float|int, 2?: string}>>  $categories
     */
    private function seedMenu(Restaurant $restaurant, array $categories): void
    {
        $categoryOrder = 0;

        foreach ($categories as $categoryName => $products) {
            // firstOrNew usa restaurant_id y name para BUSCAR, y como
            // restaurant_id no es fillable hay que asignarlo explicito.
            $category = MenuCategory::firstOrNew([
                'restaurant_id' => $restaurant->id,
                'name' => $categoryName,
            ]);
            $category->restaurant_id = $restaurant->id;
            $category->name = $categoryName;
            $category->sort_order = $categoryOrder++;
            $category->save();

            $productOrder = 0;

            foreach ($products as $product) {
                $name = $product[0];
                $price = $product[1];
                $description = $product[2] ?? null;

                $item = Product::firstOrNew([
                    'restaurant_id' => $restaurant->id,
                    'name' => $name,
                ]);

                // Asignacion directa: restaurant_id, menu_category_id e
                // is_available NO son fillable (ver App\Models\Product).
                $item->restaurant_id = $restaurant->id;
                $item->menu_category_id = $category->id;
                $item->name = $name;
                $item->description = $description;
                $item->price = $price;
                $item->is_available = true;
                $item->sort_order = $productOrder++;

                $item->save();
            }
        }
    }

    /**
     * Los menus por tipo de comida.
     *
     * Formato:  'Categoria' => [ ['Nombre', precio, 'descripcion opcional'], ... ]
     *
     * @return array<string, array<string, array<int, array<int, string|float>>>>
     */
    private function menus(): array
    {
        return [
            'tipicos' => [
                'Tipicos' => [
                    ['Pupusa de queso', 1.00, 'Hecha a mano, con curtido y salsa.'],
                    ['Pupusa de frijol con queso', 1.00],
                    ['Pupusa de chicharron', 1.25],
                    ['Yuca con chicharron', 3.50],
                    ['Sopa de pata', 4.00],
                ],
                'Bebidas' => [
                    ['Horchata', 1.00],
                    ['Jugo natural', 1.25],
                    ['Cafe negro', 0.75],
                ],
            ],

            'pizza' => [
                'Pizzas' => [
                    ['Pizza personal de pepperoni', 4.50, 'Para una persona.'],
                    ['Pizza familiar de pepperoni', 9.00],
                    ['Pizza hawaiana', 9.50],
                    ['Pizza vegetariana', 8.50],
                ],
                'Complementos' => [
                    ['Pan de ajo', 2.50],
                    ['Alitas BBQ (6)', 5.00],
                ],
                'Bebidas' => [
                    ['Gaseosa 600 ml', 1.25],
                    ['Agua pura', 0.75],
                ],
            ],

            'pollo' => [
                'Pollo' => [
                    ['Pollo frito 1/4', 4.50],
                    ['Pollo frito 1/2', 8.00],
                    ['Pollo entero', 15.00],
                    ['Alitas ala brasa (6)', 5.50],
                ],
                'Acompanamientos' => [
                    ['Papas fritas', 2.00],
                    ['Ensalada de repollo', 1.50],
                    ['Tortillas (4)', 1.00],
                ],
                'Bebidas' => [
                    ['Gaseosa 2 litros', 2.25],
                    ['Horchata', 1.00],
                ],
            ],

            'china' => [
                'Platos fuertes' => [
                    ['Arroz frito con pollo', 5.50],
                    ['Chow mein de res', 6.50],
                    ['Cerdo agridulce', 6.00],
                ],
                'Entradas' => [
                    ['Rollitos primavera (4)', 3.00],
                    ['Wantanes (6)', 3.50],
                ],
                'Bebidas' => [
                    ['Te frio', 1.25],
                    ['Gaseosa 600 ml', 1.25],
                ],
            ],

            'carnes' => [
                'Cortes' => [
                    ['Churrasco', 14.00, 'Con chimichurri y dos acompanamientos.'],
                    ['Lomito a la plancha', 12.50],
                    ['Punta de anca', 13.00],
                ],
                'Acompanamientos' => [
                    ['Papas fritas', 2.00],
                    ['Ensalada de la casa', 2.50],
                    ['Chimichurri extra', 1.00],
                ],
                'Bebidas' => [
                    ['Limonada', 1.50],
                    ['Gaseosa 600 ml', 1.25],
                ],
            ],

            'cafe' => [
                'Cafes' => [
                    ['Cafe americano', 1.25],
                    ['Capuchino', 2.00],
                    ['Cafe frio', 2.50],
                ],
                'Reposteria' => [
                    ['Cheesecake de fresa', 3.00],
                    ['Brownie con helado', 3.50],
                    ['Croissant', 1.75],
                ],
                'Desayunos' => [
                    ['Desayuno tipico', 4.50],
                    ['Pan con pollo', 2.50],
                ],
            ],

            'sandwiches' => [
                'Submarinos' => [
                    ['Sub de pollo 15 cm', 4.00],
                    ['Sub de jamon 15 cm', 3.75],
                    ['Sub de atun 15 cm', 4.00],
                    ['Sub de carne 30 cm', 7.50],
                ],
                'Complementos' => [
                    ['Galletas (3)', 1.50],
                    ['Papas', 1.25],
                ],
                'Bebidas' => [
                    ['Gaseosa 600 ml', 1.25],
                    ['Agua pura', 0.75],
                ],
            ],
        ];
    }
}
