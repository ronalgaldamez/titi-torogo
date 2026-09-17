<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Valida los datos del login.
 *
 * Va en un Form Request y no en el controlador porque asi lo pide el AGENDS:
 * "Validacion: Usar Form Requests, no validacion inline".
 */
class LoginRequest extends FormRequest
{
    /**
     * El login es publico: cualquiera puede intentarlo.
     * (Lo que protege de fuerza bruta es el rate limiting, que va aparte.)
     */
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
            'email' => ['required', 'string', 'email', 'max:255'],
            'password' => ['required', 'string'],

            // Opcional. Queda guardado en personal_access_tokens para que el
            // usuario pueda cerrar sesion solo en un telefono concreto.
            'device_name' => ['sometimes', 'string', 'max:255'],
        ];
    }

    /**
     * Mensajes en espanol (AGENDS: idioma Espanol El Salvador).
     *
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'email.required' => 'El correo es obligatorio.',
            'email.email' => 'El correo no tiene un formato valido.',
            'email.max' => 'El correo es demasiado largo.',
            'password.required' => 'La contrasena es obligatoria.',
            'device_name.max' => 'El nombre del dispositivo es demasiado largo.',
        ];
    }
}
