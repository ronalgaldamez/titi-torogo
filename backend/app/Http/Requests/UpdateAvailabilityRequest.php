<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Valida el toggle "Disponible / No disponible" del motorizado.
 *
 * El valor sale del cuerpo, pero la CUENTA sale de la sesion: no existe forma
 * de ponerse disponible en nombre de otro motorizado.
 */
class UpdateAvailabilityRequest extends FormRequest
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
            // La cadena "false" NO es valida a proposito: si alguien la manda,
            // se equivoco, y es mejor un 422 claro que un motorizado que sigue
            // sin recibir pedidos sin saber por que.
            'is_available' => ['required', 'boolean'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'is_available.required' => 'Falta indicar si estás disponible.',
            'is_available.boolean' => 'El valor tiene que ser verdadero o falso.',
        ];
    }
}
