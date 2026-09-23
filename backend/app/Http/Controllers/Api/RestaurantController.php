<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\RestaurantDetailRequest;
use App\Http\Requests\RestaurantIndexRequest;
use App\Http\Resources\DeliveryZoneResource;
use App\Http\Resources\MenuCategoryResource;
use App\Http\Resources\RestaurantResource;
use App\Models\DeliveryZone;
use App\Models\MenuCategory;
use App\Models\Restaurant;
use App\Support\Geometry;
use Illuminate\Http\JsonResponse;

/**
 * El Home del cliente.
 *
 * No pregunta "¿que restaurantes estan cerca?" sino "¿que restaurantes
 * puedo entregar donde estas?". La diferencia importa: en Tejutla puede
 * haber un restaurante a 2 km en linea recta al que no se puede llegar
 * porque esta al otro lado del cerro.
 */
class RestaurantController extends Controller
{
    /**
     * GET /api/restaurants?latitude=..&longitude=..
     *
     * Devuelve la zona del cliente y los restaurantes disponibles ahi,
     * ordenados del mas cercano al mas lejano.
     */
    public function index(RestaurantIndexRequest $request): JsonResponse
    {
        $latitude = (float) $request->validated('latitude');
        $longitude = (float) $request->validated('longitude');

        $zone = $this->findZone($latitude, $longitude);

        // Fuera de toda zona. No inventamos un error tecnico: la app recibe
        // una respuesta valida y puede mostrar "todavia no llegamos aqui",
        // que es informacion util en vez de un 500.
        if ($zone === null) {
            return response()->json([
                'zone' => null,
                'restaurants' => [],
            ]);
        }

        $restaurants = Restaurant::query()
            ->where('is_active', true)
            ->where('is_open', true)
            ->get();

        foreach ($restaurants as $restaurant) {
            // Distancia al cliente, para mostrarla y para ordenar.
            $restaurant->setAttribute('distance_km', Geometry::distanceKm(
                $latitude,
                $longitude,
                $restaurant->latitude,
                $restaurant->longitude,
            ));

            // null = hereda la tarifa de la zona (el caso normal).
            // Un valor propio es una promocion del restaurante, como
            // "envio gratis" absorbiendo el costo.
            $restaurant->setAttribute(
                'resolved_delivery_fee',
                $restaurant->delivery_fee ?? $zone->deliveryFee(),
            );
        }

        // Los mas cercanos primero: es el orden que el cliente espera.
        $restaurants = $restaurants->sortBy('distance_km')->values();

        return response()->json([
            'zone' => new DeliveryZoneResource($zone),
            'restaurants' => RestaurantResource::collection($restaurants),
        ]);
    }

    /**
     * GET /api/restaurants/{restaurant}?latitude=..&longitude=..
     *
     * El detalle: el restaurante con su menu, agrupado por categorias.
     *
     * Es la pantalla a la que se llega desde el Home — y es PUBLICA, igual
     * que el listado: el cliente mira la carta antes de crear su cuenta.
     */
    public function show(
        RestaurantDetailRequest $request,
        int $restaurant,
    ): JsonResponse {
        $model = Restaurant::query()
            ->where('is_active', true)
            ->findOrFail($restaurant);

        // AL REVES QUE EL MENU DEL RESTAURANTE: aca van solo los platos
        // DISPONIBLES.
        //
        // El dueno necesita ver los agotados para poder reactivarlos; el
        // cliente no tiene por que ver lo que hoy no hay. La misma tabla, dos
        // preguntas distintas.
        $categories = $model->menuCategories()
            ->with([
                'products' => fn ($query) => $query->where('is_available', true),
            ])
            ->get()
            // Y una categoria que se quedo SIN ningun plato disponible no se
            // muestra: una seccion vacia en la carta es ruido.
            ->filter(fn (MenuCategory $category): bool => $category->products->isNotEmpty())
            ->values();

        // La ubicacion es OPCIONAL. Si la app la mando, se resuelven la
        // distancia y la tarifa igual que en el Home; si no, las dos viajan
        // en null y la app las completa despues.
        $latitude = $request->validated('latitude');
        $longitude = $request->validated('longitude');

        if ($latitude !== null && $longitude !== null) {
            $latitude = (float) $latitude;
            $longitude = (float) $longitude;

            $model->setAttribute('distance_km', Geometry::distanceKm(
                $latitude,
                $longitude,
                $model->latitude,
                $model->longitude,
            ));

            $zone = $this->findZone($latitude, $longitude);

            // Si no hay zona, queda null: la app ya sabe mostrar "todavia no
            // llegamos ahi" y no tiene sentido inventar una tarifa.
            $model->setAttribute(
                'resolved_delivery_fee',
                $model->delivery_fee ?? $zone?->deliveryFee(),
            );
        }

        return response()->json([
            'restaurant' => new RestaurantResource($model),
            'categories' => MenuCategoryResource::collection($categories),
        ]);
    }

    /**
     * La primera zona ACTIVA que cubre el punto.
     *
     * Se recorren en PHP porque hoy hay una sola zona. Con muchas, esto se
     * resuelve con un indice geografico (PostGIS) en vez de recorrerlas.
     */
    private function findZone(float $latitude, float $longitude): ?DeliveryZone
    {
        return DeliveryZone::query()
            ->where('is_active', true)
            ->get()
            ->first(fn (DeliveryZone $zone) => $zone->contains($latitude, $longitude));
    }
}
