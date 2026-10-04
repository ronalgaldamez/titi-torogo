<?php

namespace App\Http\Requests\Admin;

use App\Enums\Vehicle;
use App\Models\User;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Valida la edicion de un motorizado desde el panel.
 *
 * Dos diferencias con el alta, y son las mismas que en restaurantes:
 *
 *   1. El correo tiene que ser unico... menos el de este mismo motorizado. Si
 *      no, guardar cualquier otro cambio daria "correo repetido" contra su
 *      propia cuenta.
 *
 *   2. La contraseña es OPCIONAL: vacia = se conserva la que tenia.
 */
class UpdateCourierRequest extends FormRequest
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
                Rule::unique('users', 'email')->ignore($this->courierId()),
            ],

            'password' => ['nullable', 'string', 'min:8', 'max:255'],
            'phone' => ['required', 'string', 'max:30'],
            'vehicle' => ['required', Rule::enum(Vehicle::class)],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'name.required' => 'Poné el nombre del motorizado.',
            'email.required' => 'Falta el correo con el que entra.',
            'email.unique' => 'Ese correo ya lo usa otra cuenta.',
            'password.min' => 'La contraseña tiene que tener al menos 8 caracteres.',
            'phone.required' => 'Falta el teléfono.',
            'vehicle.required' => 'Elegí el vehículo.',
            'vehicle.enum' => 'Ese vehículo no existe.',
        ];
    }

    /**
     * El id del motorizado que se esta editando, sacado de la ruta.
     */
    private function courierId(): int
    {
        $courier = $this->route('courier');

        return $courier instanceof User ? (int) $courier->id : 0;
    }
}
