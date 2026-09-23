<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Valida el renombrado de una categoria del menu.
 *
 * La regla del nombre repetido es la misma que al crear, con UNA diferencia:
 * se IGNORA la categoria que se esta editando.
 *
 * Sin ese ignore, guardar una categoria sin cambiarle el nombre fallaria
 * diciendo "ya tenes una categoria con ese nombre"... porque el nombre lo
 * tiene ella misma. Es el error clasico de esta regla.
 */
class UpdateMenuCategoryRequest extends FormRequest
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
            'name' => [
                'required', 'string', 'max:60',

                Rule::unique('menu_categories', 'name')
                    ->where('restaurant_id', $this->restaurantId())
                    ->whereNull('deleted_at')
                    ->ignore($this->route('category')),
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
            'name.required' => 'La categoria necesita un nombre.',
            'name.max' => 'El nombre de la categoria es demasiado largo.',
            'name.unique' => 'Ya tenes una categoria con ese nombre.',
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
