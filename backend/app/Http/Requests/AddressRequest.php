<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Valida una direccion del cliente.
 *
 * Es UNA sola clase para crear y para editar, y no es un descuido: el
 * formulario manda la direccion COMPLETA en los dos casos (es un PUT de toda
 * la ficha), asi que las reglas son las mismas. Duplicarlas en dos archivos
 * solo garantizaria que algun dia se separen.
 *
 * 'is_default' es 'sometimes' con intencion:
 *
 *   - al CREAR, si no viene, el servidor decide (la primera direccion es la
 *     predeterminada aunque nadie lo pida)
 *   - al EDITAR, si no viene, se deja como estaba
 *
 * Lo que NO se puede mandar es 'user_id': sale de la sesion.
 */
class AddressRequest extends FormRequest
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
            // "Casa", "Trabajo", "La casa de mi mama".
            'label' => ['required', 'string', 'max:60'],

            'address' => ['required', 'string', 'max:255'],

            // "Frente a la farmacia". Opcional, pero es lo que hace que el
            // motorizado llegue en Tejutla.
            'reference' => ['sometimes', 'nullable', 'string', 'max:255'],

            // decimal(10,7) en la base: se valida el rango del planeta, no la
            // cantidad de decimales (la base la ajusta sola).
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],

            'is_default' => ['sometimes', 'boolean'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'label.required' => 'Poné un nombre para reconocerla (Casa, Trabajo...).',
            'label.max' => 'El nombre es demasiado largo.',

            'address.required' => 'Falta la dirección.',
            'address.max' => 'La dirección es demasiado larga.',

            'reference.max' => 'La referencia es demasiado larga.',

            'latitude.required' => 'Falta la ubicación.',
            'latitude.numeric' => 'La ubicación no es válida.',
            'latitude.between' => 'La ubicación no es válida.',

            'longitude.required' => 'Falta la ubicación.',
            'longitude.numeric' => 'La ubicación no es válida.',
            'longitude.between' => 'La ubicación no es válida.',

            'is_default.boolean' => 'El valor tiene que ser verdadero o falso.',
        ];
    }
}
