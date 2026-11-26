<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;

/** Se usa solo en las rutas de compra y seguimiento del titular. */
class CustomerOrderResource extends OrderResource
{
    public function toArray(Request $request): array
    {
        return [
            ...parent::toArray($request),
            'delivery_pin' => $this->when(
                $this->status->isActive()
                    && $request->user()?->id === $this->user_id
                    && $this->courier_id !== $this->user_id,
                fn () => $this->delivery_pin,
            ),
        ];
    }
}
