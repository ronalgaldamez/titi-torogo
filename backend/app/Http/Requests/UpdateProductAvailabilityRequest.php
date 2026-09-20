<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Valida el toggle de "se me acabo" de un plato.
 *
 * Es un endpoint aparte y no parte de la edicion del producto por dos
 * razones:
 *
 *   1. En la lista, el restaurante apaga un plato de un toque. Mandar el
 *      producto completo para eso seria cargar y reenviar todo el plato.
 *   2. 'is_available' NO es fillable. Si se pudiera cambiar desde el
 *      endpoint de edicion, el restaurante podria resucitar un plato
 *      mandando el JSON completo. Aqui es el UNICO lugar donde cambia.
 */
class UpdateProductAvailabilityRequest extends FormRequest
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
            // 'boolean' acepta true/false/1/0. OJO: la cadena "false" NO es
            // valida a proposito — si alguien la manda, se equivoco, y es
            // mejor un 422 claro que un plato que sigue agotado sin saber por que.
            'is_available' => ['required', 'boolean'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'is_available.required' => 'Falta indicar si el plato esta disponible.',
            'is_available.boolean' => 'El valor tiene que ser verdadero o falso.',
        ];
    }
}
