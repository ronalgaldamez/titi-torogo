<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Una direccion guardada, tal como la ve el cliente.
 *
 * @mixin \App\Models\Address
 */
class AddressResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'label' => $this->label,
            'address' => $this->address,
            'reference' => $this->reference,

            // Las coordenadas viajan como numero: van al mapa.
            'latitude' => $this->latitude,
            'longitude' => $this->longitude,

            // La que viene elegida en el checkout.
            'is_default' => $this->is_default,
        ];
    }
}
