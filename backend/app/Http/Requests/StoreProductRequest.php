<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Valida la creacion de un producto del menu.
 *
 * Del body NUNCA se toman 'restaurant_id' (sale de la sesion) ni
 * 'is_available' (un plato nuevo nace disponible; apagarlo es otra accion,
 * la del toggle de la lista).
 *
 * El campo delicado es 'menu_category_id'. No basta con validar que la
 * categoria EXISTA: tiene que ser del mismo restaurante. Si no, alguien
 * podria mandar el id de una categoria ajena y dejar su producto colgando
 * del menu de otro.
 */
class StoreProductRequest extends FormRequest
{
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
            'name' => ['required', 'string', 'max:120'],
            'description' => ['sometimes', 'nullable', 'string', 'max:500'],

            // decimal:0,2 -> entre 0 y 2 decimales, igual que la columna
            // decimal(8,2). Sin esa regla, un "1.005" entra y la base lo
            // redondea sola: el cliente ve un precio que el restaurante
            // nunca escribio.
            // min:0 permite un plato gratis (una salsa extra, por ejemplo).
            'price' => ['required', 'numeric', 'decimal:0,2', 'min:0', 'max:999999.99'],

            // null = el plato queda sin clasificar y el restaurante lo
            // reacomoda despues. Pero si viene una categoria, TIENE que ser
            // suya. whereNull('deleted_at') para no aceptar una borrada.
            'menu_category_id' => [
                'sometimes', 'nullable', 'integer',
                Rule::exists('menu_categories', 'id')
                    ->where('restaurant_id', $this->restaurantId())
                    ->whereNull('deleted_at'),
            ],

            // Opcional: si no lo mandan, va al final.
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
            'name.required' => 'El producto necesita un nombre.',
            'name.max' => 'El nombre del producto es demasiado largo.',
            'description.max' => 'La descripcion es demasiado larga.',

            'price.required' => 'El producto necesita un precio.',
            'price.numeric' => 'El precio no es valido.',
            'price.decimal' => 'El precio solo puede tener dos decimales.',
            'price.min' => 'El precio no puede ser negativo.',
            'price.max' => 'El precio es demasiado alto.',

            'menu_category_id.exists' => 'Esa categoria no es de tu menu.',

            'sort_order.integer' => 'El orden debe ser un numero.',
            'sort_order.min' => 'El orden no puede ser negativo.',
            'sort_order.max' => 'El orden es demasiado alto.',
        ];
    }

    private function restaurantId(): int
    {
        return (int) $this->user()->restaurant->id;
    }
}
