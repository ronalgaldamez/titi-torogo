<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * La zona de reparto tal como la ve la app.
 *
 * Se mandan las DOS lineas por separado a proposito: la app las muestra
 * desglosadas en el recibo, y asi el cliente ve que el envio va completo
 * al motorizado y que el servicio es de ToroGo.
 *
 * @mixin \App\Models\DeliveryZone
 */
class DeliveryZoneResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,

            // Total que paga el cliente (calculado, no guardado).
            'delivery_fee' => $this->deliveryFee(),

            // El desglose, para mostrarlo en el recibo.
            'courier_fee' => $this->courier_fee,
            'platform_fee' => $this->platform_fee,
        ];
    }
}
