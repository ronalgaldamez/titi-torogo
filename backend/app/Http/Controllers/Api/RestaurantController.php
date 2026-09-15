<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\RestaurantIndexRequest;
use App\Http\Resources\DeliveryZoneResource;
use App\Http\Resources\RestaurantResource;
use App\Models\DeliveryZone;
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
