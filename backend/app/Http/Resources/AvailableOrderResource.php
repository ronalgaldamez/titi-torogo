<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;

/** La lista previa a tomar un pedido nunca incluye datos de entrega. */
class AvailableOrderResource extends OrderResource
{
    public function toArray(Request $request): array
    {
        $data = parent::toArray($request);
        unset($data['delivery'], $data['notes']);

        return $data;
    }
}
