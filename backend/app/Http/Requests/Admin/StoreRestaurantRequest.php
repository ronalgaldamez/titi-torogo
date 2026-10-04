<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Valida el alta de un restaurante desde el panel.
 *
 * Un restaurante son DOS cosas: la cuenta con la que entra a la app (users) y
 * la ficha del local (restaurants). Por eso este formulario pide las dos.
 *
 * El perfil NO se pide: se fuerza en el controlador (UserRole::Restaurant),
 * igual que en el registro de clientes. Si viniera del formulario, cualquiera
 * podria crear un administrador mandando un campo de mas.
 */
class StoreRestaurantRequest extends FormRequest
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
            // ------------------------- La cuenta -------------------------

            // El nombre se usa para las dos cosas: el local y la cuenta de su
            // dueno. Es lo que hace el seeder, y evita pedir dos veces lo
            // mismo.
            'name' => ['required', 'string', 'max:255'],

            // unique en users: dos locales no pueden entrar con el mismo
            // correo, porque el login no sabria a cual de los dos dejar pasar.
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8', 'max:255'],

            // -------------------------- El local --------------------------

            'description' => ['nullable', 'string', 'max:255'],
            'address' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'max:30'],

            // Las coordenadas son OBLIGATORIAS: sin ellas no se puede calcular
            // la distancia ni dibujar el local en el mapa del cliente.
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],

            'prep_time_minutes' => ['required', 'integer', 'min:1', 'max:180'],

            // Vacío = hereda la tarifa de la zona (el caso normal). Un valor
            // propio es una promocion del local, como "envio gratis".
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
            'email.required' => 'Falta el correo con el que va a entrar.',
            'email.unique' => 'Ya hay una cuenta con ese correo.',
            'password.required' => 'Poné una contraseña.',
            'password.min' => 'La contraseña tiene que tener al menos 8 caracteres.',
            'address.required' => 'Falta la dirección.',
            'phone.required' => 'Falta el teléfono.',
            'latitude.required' => 'Faltan las coordenadas.',
            'longitude.required' => 'Faltan las coordenadas.',
            'prep_time_minutes.required' => 'Poné cuánto tardás en preparar un pedido.',
            'delivery_fee.numeric' => 'La tarifa tiene que ser un número (o dejarla vacía).',
        ];
    }
}
