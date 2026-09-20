<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Valida la edicion de un producto del menu.
 *
 * OJO con 'description' y 'menu_category_id': son 'sometimes' A PROPOSITO.
 * Hay TRES casos que a simple vista parecen dos:
 *
 *   - el campo NO viene        -> se deja como estaba
 *   - el campo viene en null   -> se borra (queda sin descripcion / sin categoria)
 *   - el campo viene con valor -> se cambia
 *
 * Por eso el controlador usa array_key_exists() y no '??'. Con '??', guardar
 * el formulario sin tocar la descripcion la borraria sin que nadie lo pida.
 *
 * 'restaurant_id' e 'is_available' NO estan aqui: el primero sale de la
 * sesion, y el segundo tiene su propio endpoint (el toggle de agotado).
 */
class UpdateProductRequest extends FormRequest
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

            'price' => ['required', 'numeric', 'decimal:0,2', 'min:0', 'max:999999.99'],

            'menu_category_id' => [
                'sometimes', 'nullable', 'integer',
                Rule::exists('menu_categories', 'id')
                    ->where('restaurant_id', $this->restaurantId())
                    ->whereNull('deleted_at'),
            ],

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
