<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Transforma un User antes de mandarlo a la app.
 *
 * El AGENDS lo pide: "API Resources: Transformar datos antes de enviarlos
 * al frontend". Asi el modelo puede cambiar sin romper a Flutter, y jamas
 * se filtra el hash de la contrasena por accidente.
 *
 * @mixin \App\Models\User
 */
class UserResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'role' => $this->role->value,
            'role_label' => $this->role->label(),

            // Solo lo usa el motorizado ("Disponible / No disponible"). Va en
            // el usuario y no en un pedido porque es el estado de la PERSONA:
            // sirve para saber si esta trabajando en este momento. En los
            // otros perfiles viaja en false y a nadie le importa.
            'is_available' => (bool) $this->is_available,
            'email_verified_at' => $this->email_verified_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
