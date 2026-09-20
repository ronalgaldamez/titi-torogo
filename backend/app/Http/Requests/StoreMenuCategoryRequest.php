<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Valida la creacion de una categoria del menu.
 *
 * OJO: aqui NO existe la regla 'restaurant_id'. La categoria se cuelga del
 * restaurante de la SESION, no del JSON que llega (ver
 * MenuController::storeCategory). Si fuera un campo del body, un restaurante
 * podria meterle categorias al menu de otro mandando un id ajeno. Es la misma
 * barrera que ya tiene 'role' en User y 'user_id' en Restaurant.
 */
class StoreMenuCategoryRequest extends FormRequest
{
    /**
     * El permiso ya lo dio el middleware 'restaurant' en la ruta: si el codigo
     * llego hasta aqui, la cuenta es de restaurante y tiene su ficha.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        return [
            'name' => [
                'required', 'string', 'max:60',

                // Dos veces "Bebidas" en el mismo menu no aporta nada y
                // confunde al cliente. El whereNull('deleted_at') es la parte
                // importante: una categoria BORRADA no debe impedir volver a
                // crear una con ese nombre.
                Rule::unique('menu_categories', 'name')
                    ->where('restaurant_id', $this->restaurantId())
                    ->whereNull('deleted_at'),
            ],

            // Opcional. Si no lo mandan, el controlador la pone al final.
            // max:65535 porque la columna es unsignedSmallInteger.
            'sort_order' => ['sometimes', 'integer', 'min:0', 'max:65535'],
        ];
    }

    /**
     * Mensajes en espanol.
     *
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'name.required' => 'La categoria necesita un nombre.',
            'name.max' => 'El nombre de la categoria es demasiado largo.',
            'name.unique' => 'Ya tenes una categoria con ese nombre.',
            'sort_order.integer' => 'El orden debe ser un numero.',
            'sort_order.min' => 'El orden no puede ser negativo.',
            'sort_order.max' => 'El orden es demasiado alto.',
        ];
    }

    /**
     * El id del restaurante de la sesion.
     *
     * El middleware de la ruta ya garantizo que la relacion existe, asi que
     * aqui nunca es null.
     */
    private function restaurantId(): int
    {
        return (int) $this->user()->restaurant->id;
    }
}
