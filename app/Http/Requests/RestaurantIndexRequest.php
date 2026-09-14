<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Valida la ubicacion del cliente para el Home.
 *
 * El Home de ToroGo es "restaurantes que puedo entregar donde estas", asi
 * que sin ubicacion no hay respuesta posible. La app Flutter pide el permiso
 * de GPS ANTES de llamar aqui, para que el usuario vea una peticion clara
 * y no un error tecnico.
 */
class RestaurantIndexRequest extends FormRequest
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
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'latitude.required' => 'Necesitamos tu ubicacion para mostrarte los restaurantes.',
            'latitude.numeric' => 'La latitud no es valida.',
            'latitude.between' => 'La latitud no es valida.',
            'longitude.required' => 'Necesitamos tu ubicacion para mostrarte los restaurantes.',
            'longitude.numeric' => 'La longitud no es valida.',
            'longitude.between' => 'La longitud no es valida.',
        ];
    }
}
