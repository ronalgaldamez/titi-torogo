<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RestaurantCategoryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'icon_key' => $this->icon_key,
            // Ruta relativa: funciona tanto en localhost como desde el emulador.
            'icon_url' => $this->icon_path
                ? route('api.category.icon', $this->id, false).'?v='.sha1($this->icon_path)
                : null,
        ];
    }
}
