<?php

namespace Database\Seeders;

use App\Models\MenuCategory;
use App\Models\Product;
use App\Models\Restaurant;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class BarukMenuSeeder extends Seeder
{
    public function run(): void
    {
        $items = [
            ['Burrito momia', '8.75', 'Burrito mexicano envuelto en tocino.', 'burrito-momia.jpg'],
            ['Rib eye', '17.00', 'Corte de res premium a la parrilla. Cuatro acompañamientos de tu elección.', 'rib-eye.jpg'],
            ['Taquiza Pastora', '13.50', '10 tacos al pastor, acompañados de jalapeño toreado, chirimol y salsa verde.', 'taquiza-pastora.jpg'],
        ];
        foreach ($items as $item) {
            if (! is_file(database_path('data/baruk/'.$item[3]))) {
                throw new \RuntimeException('Falta la foto original de '.$item[0].'.');
            }
        }
        $disk = Storage::disk('s3');
        $uploaded = [];

        try {
            DB::transaction(function () use ($items, $disk, &$uploaded) {
                $restaurant = Restaurant::whereHas('user', fn ($query) => $query->where('email', 'sombreron@torogo.local'))
                    ->lockForUpdate()->firstOrFail();
                $restaurant->media_directory ??= 'negocios/'.Str::substr(Str::slug($restaurant->name) ?: 'local', 0, 80).'-'.$restaurant->id;
                if ($restaurant->isDirty()) {
                    $restaurant->save();
                }
                $category = MenuCategory::firstOrNew(['restaurant_id' => $restaurant->id, 'name' => 'Especialidades']);
                if (! $category->exists) {
                    $category->restaurant_id = $restaurant->id;
                    $category->sort_order = ((int) $restaurant->menuCategories()->max('sort_order')) + 1;
                    $category->save();
                }
                foreach ($items as [$name, $price, $description, $filename]) {
                    $product = Product::withTrashed()->where('restaurant_id', $restaurant->id)->where('name', $name)->first();
                    if ($product?->trashed()) {
                        $product->restore();
                    }
                    if ($product === null) {
                        $product = new Product;
                        $product->restaurant_id = $restaurant->id;
                        $product->menu_category_id = $category->id;
                        $product->name = $name;
                        $product->price = $price;
                        $product->description = $description;
                        $product->is_available = true;
                        $product->sort_order = ((int) $restaurant->products()->max('sort_order')) + 1;
                        $product->save();
                    }
                    // Un segundo seeding no pisa precios, disponibilidad ni fotos editados desde la app.
                    if ($product->image_path) {
                        continue;
                    }
                    $path = $restaurant->media_directory.'/platos/'.$product->id.'/'.$filename;
                    if (! $disk->exists($path)) {
                        $stream = fopen(database_path('data/baruk/'.$filename), 'rb');
                        if ($stream === false) {
                            throw new \RuntimeException('No se pudo abrir la foto de '.$name.'.');
                        }
                        try {
                            if (! $disk->put($path, $stream)) {
                                throw new \RuntimeException('No se pudo subir la foto de '.$name.'.');
                            }
                            $uploaded[] = $path;
                        } finally {
                            fclose($stream);
                        }
                    }
                    $product->image_path = $path;
                    $product->save();
                }
                // Solo se retiran del menú de Baruk; el historial conserva las filas y sus fotos.
                $restaurant->products()->whereNotIn('name', array_column($items, 0))->delete();
            });
        } catch (\Throwable $error) {
            foreach ($uploaded as $path) {
                try {
                    if (! $disk->delete($path)) {
                        report(new \RuntimeException('No se pudo limpiar una foto de la carga de Baruk.'));
                    }
                } catch (\Throwable $cleanupError) {
                    report($cleanupError);
                }
            }
            throw $error;
        }
    }
}
