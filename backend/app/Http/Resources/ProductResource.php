<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/**
 * Un producto del menu, tal como lo ve el restaurante que lo administra.
 *
 * Se manda 'image_url' y no 'image_path': la app no tiene por que saber que
 * los archivos viven en S3 privado ni armar rutas. El backend entrega una URL firmada.
 *
 * @mixin \App\Models\Product
 */
class ProductResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'description' => $this->description,

            // 'decimal:2' en el modelo -> viaja como TEXTO ("3.50"), nunca
            // como numero. Si viajara como numero, Flutter lo leeria double
            // y al sumar el carrito aparecerian centavos fantasma.
            'price' => $this->resource->effectivePrice(),
            'regular_price' => $this->price,
            'offer_enabled' => (bool) $this->offer_enabled,
            'sale_price' => $this->sale_price,
            'offer_starts_at' => $this->offer_starts_at?->toIso8601String(),
            'offer_ends_at' => $this->offer_ends_at?->toIso8601String(),

            'image_url' => $this->image_path
                ? Storage::disk('s3')->temporaryUrl($this->image_path, now()->addHour())
                : null,

            // Aqui SI van los agotados. Al contrario que la carta publica
            // (que solo muestra lo disponible), el restaurante necesita ver
            // los que apago: son justo los que viene a reactivar.
            'is_available' => $this->is_available,

            'sort_order' => $this->sort_order,
        ];
    }
}
