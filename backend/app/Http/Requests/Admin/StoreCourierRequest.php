<?php

namespace App\Http\Requests\Admin;

use App\Enums\Vehicle;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Valida el alta de un motorizado desde el panel.
 *
 * A diferencia del restaurante, aca NO hay dos filas: el motorizado es una sola
 * cuenta (users) con role = courier. Por eso no hace falta transaccion.
 *
 * El rol NO se pide: se fuerza en el controlador, igual que en el registro de
 * clientes. Si viniera del formulario, cualquiera podria crear un
 * administrador mandando un campo de mas.
 */
class StoreCourierRequest extends FormRequest
{
    public function authorize(): bool
    {
        // Quien llega hasta aca ya paso por el middleware 'admin'.
        return true;
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'max:255'],

            // El telefono es obligatorio: es el dato con el que se lo ubica
            // cuando un pedido se traba, y el cliente lo ve en el seguimiento.
            'phone' => ['required', 'string', 'max:30'],

            // Rule::enum y no 'in:...': si manana se suma un vehiculo al enum,
            // la validacion lo acepta sola y no hay que acordarse de esta linea.
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
            'email.required' => 'Falta el correo con el que va a entrar.',
            'email.unique' => 'Ya hay una cuenta con ese correo.',
            'password.required' => 'Poné una contraseña.',
            'password.min' => 'La contraseña tiene que tener al menos 8 caracteres.',
            'phone.required' => 'Falta el teléfono.',
            'vehicle.required' => 'Elegí el vehículo.',
            'vehicle.enum' => 'Ese vehículo no existe.',
        ];
    }
}
