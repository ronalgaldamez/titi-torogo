<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Un pedido tal como lo ve la app.
 *
 * El dinero va como TEXTO ("10.50"), igual que en el resto de la API.
 *
 * @mixin \App\Models\Order
 */
class OrderResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,

            // El valor tecnico ('pending') y la etiqueta ('Pendiente'). La app
            // decide con el valor y muestra la etiqueta.
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'is_active' => $this->status->isActive(),

            'restaurant' => [
                'id' => $this->restaurant->id,
                'name' => $this->restaurant->name,
                'address' => $this->restaurant->address,
                'latitude' => $this->restaurant->latitude,
                'longitude' => $this->restaurant->longitude,
            ],

            // La COPIA de la direccion de entrega, no la que el cliente tenga
            // hoy guardada. Es a donde se llevo el pedido de verdad.
            'delivery' => [
                'address' => $this->delivery_address,
                'reference' => $this->delivery_reference,
                'latitude' => $this->delivery_latitude,
                'longitude' => $this->delivery_longitude,
            ],

            'items' => OrderItemResource::collection($this->whenLoaded('items')),

            // El motorizado, cuando ya lo tomo. Va con whenLoaded: si el
            // controlador no lo pidio, la clave ni aparece.
            //
            // El telefono todavia NO va: la tabla users no tiene esa columna.
            // Cuando la agreguemos (el perfil del motorizado la pide en la
            // biblia), el cliente va a poder llamarlo desde el seguimiento.
            'courier' => $this->whenLoaded(
                'courier',
                fn (): ?array => $this->courier === null ? null : [
                    'id' => $this->courier->id,
                    'name' => $this->courier->name,
                ],
            ),

            // El desglose, tal como el cliente lo vio en el checkout.
            'subtotal' => $this->subtotal,
            'delivery_fee' => $this->delivery_fee,
            'courier_fee' => $this->courier_fee,
            'platform_fee' => $this->platform_fee,
            'total' => $this->total,

            'payment_method' => $this->payment_method,
            'notes' => $this->notes,

            // El recorrido. Null = todavia no paso por ahi.
            'accepted_at' => $this->accepted_at?->toIso8601String(),
            'ready_at' => $this->ready_at?->toIso8601String(),
            'picked_up_at' => $this->picked_up_at?->toIso8601String(),
            'delivered_at' => $this->delivered_at?->toIso8601String(),
            'cancelled_at' => $this->cancelled_at?->toIso8601String(),

            'created_at' => $this->created_at?->toIso8601String(),

            // Distancia del motorizado al RESTAURANTE, y solo cuando la pide
            // (ver CourierOrderController::available). En los demas casos
            // viaja null, porque nadie la calculo.
            'distance_km' => isset($this->distance_km)
                ? round((float) $this->distance_km, 1)
                : null,
        ];
    }
}
