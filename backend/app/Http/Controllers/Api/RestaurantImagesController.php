<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateRestaurantImagesRequest;
use App\Http\Resources\RestaurantResource;
use App\Models\Restaurant;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

class RestaurantImagesController extends Controller
{
    public function update(UpdateRestaurantImagesRequest $request)
    {
        $disk = Storage::disk('s3');
        $created = [];
        $replaced = [];

        try {
            $restaurant = DB::transaction(function () use ($request, $disk, &$created, &$replaced) {
                $restaurant = Restaurant::whereKey($request->user()->restaurant->id)->lockForUpdate()->firstOrFail();
                // El prefijo se fija una vez: renombrar el negocio no rompe las imágenes.
                $restaurant->media_directory ??= 'negocios/'.Str::substr(Str::slug($restaurant->name) ?: 'local', 0, 80).'-'.$restaurant->id;
                foreach (['logo' => 'logo_path', 'cover' => 'cover_path'] as $input => $column) {
                    if (! $request->hasFile($input)) {
                        continue;
                    }
                    $directory = $restaurant->media_directory.'/'.($input === 'cover' ? 'portada' : 'logo');
                    $path = $disk->putFile($directory, $request->file($input));
                    abort_if($path === false, 503, 'No pudimos guardar las imágenes. Intentá de nuevo.');
                    $created[] = $path;
                    if ($restaurant->$column) {
                        $replaced[] = $restaurant->$column;
                    }
                    $restaurant->$column = $path;
                }
                $restaurant->save();

                return $restaurant;
            });
        } catch (\Throwable $error) {
            $this->cleanUp($created);
            report($error);
            abort(503, 'No pudimos guardar las imágenes. Intentá de nuevo.');
        }

        $this->cleanUp($replaced);

        return response()->json(['restaurant' => new RestaurantResource($restaurant->load('categories'))]);
    }

    private function cleanUp(array $paths): void
    {
        foreach ($paths as $path) {
            try {
                if (! Storage::disk('s3')->delete($path)) {
                    report(new \RuntimeException('No se pudo limpiar una imagen reemplazada de restaurante.'));
                }
            } catch (\Throwable $error) {
                report($error);
            }
        }
    }
}
