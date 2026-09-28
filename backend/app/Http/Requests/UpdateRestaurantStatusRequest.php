<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Valida el interruptor del restaurante: abierto/cerrado y "muy ocupado".
 *
 * Los dos valores salen del cuerpo, pero el RESTAURANTE sale de la sesion (ver
 * EnsureRestaurantAccount): no existe forma de cerrar el local de otro.
 */
class UpdateRestaurantStatusRequest extends FormRequest
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
            // Los dos son OBLIGATORIOS: el dashboard manda siempre el estado
            // completo. Si cada uno fuera opcional, un dia se cambiaria uno
            // creyendo que se cambio el otro.
            //
            // 'boolean' acepta true/false de verdad. La cadena "false" NO, a
            // proposito: si alguien la manda, se equivoco, y es mejor un 422
            // claro que un restaurante que se cree cerrado y no recibe nada.
            'is_open' => ['required', 'boolean'],
            'is_busy' => ['required', 'boolean'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'is_open.required' => 'Falta indicar si el local está abierto.',
            'is_open.boolean' => 'El valor tiene que ser verdadero o falso.',
            'is_busy.required' => 'Falta indicar si estás muy ocupado.',
            'is_busy.boolean' => 'El valor tiene que ser verdadero o falso.',
        ];
    }
}
