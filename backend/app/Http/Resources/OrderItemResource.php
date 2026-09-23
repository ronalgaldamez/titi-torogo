<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Una linea del pedido.
 *
 * El nombre y el precio son la COPIA que se guardo al comprar, no los del
 * plato de hoy: si el restaurante sube el precio manana, este pedido sigue
 * mostrando lo que se pago.
 *
 * @mixin \App\Models\OrderItem
 */
class OrderItemResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,

            // Puede ser null si el restaurante borro el plato despues. La
            // linea igual muestra su nombre y su precio.
            'product_id' => $this->product_id,

            'name' => $this->name,
            'unit_price' => $this->unit_price,
            'quantity' => $this->quantity,
            'subtotal' => $this->subtotal,
        ];
    }
}
