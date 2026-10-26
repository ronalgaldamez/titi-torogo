<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/**
 * Un restaurante tal como lo ve el cliente en el Home.
 *
 * 'distance_km' y 'resolved_delivery_fee' no son columnas de la tabla:
 * el controlador las calcula para cada restaurante antes de transformarlo
 * (ver RestaurantController::index).
 *
 * @mixin \App\Models\Restaurant
 */
class RestaurantResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'food_categories' => RestaurantCategoryResource::collection($this->whenLoaded('categories')),
            'description' => $this->description,
            'address' => $this->address,
            'phone' => $this->phone,

            // URLs firmadas: S3 permanece privado. Se renuevan al consultar el local.
            'logo_url' => $this->logo_path
                ? Storage::disk('s3')->temporaryUrl($this->logo_path, now()->addHour())
                : null,
            'cover_url' => $this->cover_path
                ? Storage::disk('s3')->temporaryUrl($this->cover_path, now()->addHour())
                : null,

            'latitude' => $this->latitude,
            'longitude' => $this->longitude,

            'is_open' => $this->is_open,
            'is_busy' => $this->is_busy,

            // Tiempo ya calculado: si esta "muy ocupado", el modelo le suma 50%.
            'prep_time_minutes' => $this->preparationMaximumMinutes(),
            'prep_time_min_minutes' => $this->preparationMinimumMinutes(),
            'prep_time_max_minutes' => $this->preparationMaximumMinutes(),
            'estimated_prep_min_minutes' => $this->estimatedPreparationMinimumMinutes(),
            'estimated_prep_max_minutes' => $this->estimatedDeliveryMinutes(),
            'estimated_delivery_minutes' => $this->estimatedDeliveryMinutes(),

            // Distancia al cliente en km, redondeada a 1 decimal ("a 1.2 km").
            'distance_km' => isset($this->distance_km)
                ? round((float) $this->distance_km, 1)
                : null,

            // Tarifa final: la propia si es una promocion, o la de la zona.
            'delivery_fee' => $this->resolved_delivery_fee ?? null,
        ];
    }
}
