<?php

namespace App\Http\Requests\Admin;

use App\Models\Restaurant;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Valida la edicion de un restaurante desde el panel.
 *
 * Es casi igual a StoreRestaurantRequest, con DOS diferencias que importan:
 *
 *   1. El correo tiene que ser unico... menos el de este mismo local. Si no,
 *      guardar cualquier otro cambio daria error por "correo repetido" contra
 *      su propia cuenta.
 *
 *   2. La contraseña es OPCIONAL. Si se deja vacia, se conserva la que tenia:
 *      corregir un telefono no tiene por que obligar a cambiarla.
 */
class UpdateRestaurantRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],

            'email' => [
                'required',
                'email',
                'max:255',
                // El "ignore" es el id del dueno de ESTE restaurante.
                Rule::unique('users', 'email')->ignore($this->ownerId()),
            ],

            // nullable y no required: vacia = se queda la de antes.
            'password' => ['nullable', 'string', 'min:8', 'max:255'],

            'description' => ['nullable', 'string', 'max:255'],
            'address' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:30'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'prep_time_minutes' => ['required', 'integer', 'min:1', 'max:180'],
            'delivery_fee' => ['nullable', 'numeric', 'min:0', 'max:100'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'name.required' => 'Poné el nombre del local.',
            'email.required' => 'Falta el correo con el que entra.',
            'email.unique' => 'Ese correo ya lo usa otra cuenta.',
            'password.min' => 'La contraseña tiene que tener al menos 8 caracteres.',
            'address.required' => 'Falta la dirección.',
            'phone.required' => 'Falta el teléfono.',
            'latitude.required' => 'Faltan las coordenadas.',
            'longitude.required' => 'Faltan las coordenadas.',
            'prep_time_minutes.required' => 'Poné cuánto tardás en preparar un pedido.',
            'delivery_fee.numeric' => 'La tarifa tiene que ser un número (o dejarla vacía).',
        ];
    }

    /**
     * El id de la cuenta duena del restaurante que se esta editando.
     *
     * Sale de la ruta, del modelo que Laravel ya resolvio por el {restaurant}.
     * Si por lo que sea no estuviera, se devuelve 0 y la regla unique queda
     * igual de estricta (no ignora a nadie).
     */
    private function ownerId(): int
    {
        $restaurant = $this->route('restaurant');

        return $restaurant instanceof Restaurant
            ? (int) $restaurant->user_id
            : 0;
    }
}
