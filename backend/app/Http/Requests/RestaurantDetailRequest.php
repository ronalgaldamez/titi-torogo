<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Valida la ubicacion OPCIONAL al pedir el detalle de un restaurante.
 *
 * A diferencia del Home (RestaurantIndexRequest), aca la ubicacion NO es
 * obligatoria: el detalle se puede abrir sin saber donde esta el cliente.
 *
 * Si viene, se usa para calcular la distancia y resolver la tarifa de envio.
 * Si no viene, esos dos datos viajan en null — y esta bien, porque la app los
 * completa cuando ya tiene el GPS.
 */
class RestaurantDetailRequest extends FormRequest
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
            'latitude' => ['sometimes', 'numeric', 'between:-90,90'],
            'longitude' => ['sometimes', 'numeric', 'between:-180,180'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'latitude.numeric' => 'La latitud no es valida.',
            'latitude.between' => 'La latitud no es valida.',
            'longitude.numeric' => 'La longitud no es valida.',
            'longitude.between' => 'La longitud no es valida.',
        ];
    }
}
