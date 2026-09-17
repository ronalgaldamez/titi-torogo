<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

/**
 * Valida los datos del registro de un CLIENTE.
 *
 * OJO: aqui NO existe la regla 'role'. Eso es a proposito — el perfil se
 * fuerza en el servidor (ver AuthController::register). Restaurante,
 * Motorizado y Admin no se registran solos: los crea el administrador.
 */
class RegisterRequest extends FormRequest
{
    /**
     * El registro de clientes es publico.
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
            'name' => ['required', 'string', 'max:255'],

            // Rule::unique evita que dos personas usen el mismo correo.
            // Compara contra la tabla users completa, asi que un correo ya
            // usado por un restaurante tampoco se puede reutilizar.
            'email' => ['required', 'string', 'email', 'max:255', Rule::unique('users', 'email')],

            // 'confirmed' exige que venga tambien password_confirmation
            // y que ambos coincidan.
            'password' => ['required', 'string', 'confirmed', Password::min(8)],

            'device_name' => ['sometimes', 'string', 'max:255'],
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
            'name.required' => 'El nombre es obligatorio.',
            'name.max' => 'El nombre es demasiado largo.',

            'email.required' => 'El correo es obligatorio.',
            'email.email' => 'El correo no tiene un formato valido.',
            'email.max' => 'El correo es demasiado largo.',
            'email.unique' => 'Ese correo ya esta registrado.',

            'password.required' => 'La contrasena es obligatoria.',
            'password.confirmed' => 'Las contrasenas no coinciden.',
            'password.min' => 'La contrasena debe tener al menos 8 caracteres.',

            'device_name.max' => 'El nombre del dispositivo es demasiado largo.',
        ];
    }
}
