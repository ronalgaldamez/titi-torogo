<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Una categoria del menu, con sus productos adentro.
 *
 * El menu no se aplana a una lista de productos: la pantalla del restaurante
 * los muestra agrupados ("Tipicos", "Bebidas"), y las categorias vacias
 * tienen que llegar igual porque son las que acaba de crear.
 *
 * whenLoaded('products'): los productos solo salen si el controlador los
 * pidio con ->with('products'). Asi el mismo recurso sirve para la pantalla
 * del menu completo y para una que solo liste categorias, sin consultas de
 * mas ni problemas de N+1.
 *
 * @mixin \App\Models\MenuCategory
 */
class MenuCategoryResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'sort_order' => $this->sort_order,
            'products' => ProductResource::collection($this->whenLoaded('products')),
        ];
    }
}
