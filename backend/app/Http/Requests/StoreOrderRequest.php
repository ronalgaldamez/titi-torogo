<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Valida la FORMA del pedido que manda el cliente.
 *
 * OJO con lo que NO esta aqui: precios, subtotales y totales.
 *
 * El pedido trae QUE platos y CUANTAS unidades. Todo el dinero lo calcula el
 * servidor leyendo el catalogo. Si aceptaramos un precio desde el JSON,
 * cualquiera pediria una pupusa a un centavo y el sistema le creeria.
 *
 * Tampoco esta 'user_id': sale de la sesion.
 */
class StoreOrderRequest extends FormRequest
{
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
            'restaurant_id' => ['required', 'integer'],

            // La direccion guardada que eligio el cliente. Que sea SUYA se
            // verifica en el controlador con findOrFail sobre la relacion:
            // aqui no se puede, porque esta regla no sabe quien esta pidiendo.
            'address_id' => ['required', 'integer'],

            // Tope de 50 lineas: un pedido de delivery real no tiene mas. Sin
            // tope, alguien podria mandar diez mil lineas y tumbar el servidor
            // armando la cuenta.
            'items' => ['required', 'array', 'min:1', 'max:50'],

            'items.*.product_id' => ['required', 'integer'],

            // min:1 para que nadie mande una linea de cero unidades: sumaria
            // 0.00 y ensuciaria la cuenta del pedido.
            'items.*.quantity' => ['required', 'integer', 'min:1', 'max:99'],

            'notes' => ['sometimes', 'nullable', 'string', 'max:255'],

            // La clave contra el doble cobro (AGENDS: "Idempotencia"). La app
            // la genera una vez por checkout y la REPITE si tiene que
            // reintentar, para que el reintento no cree un segundo pedido.
            'idempotency_key' => ['required', 'string', 'min:8', 'max:64'],
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
            'restaurant_id.required' => 'Falta el restaurante.',
            'address_id.required' => 'Elegí a dónde te lo llevamos.',

            'items.required' => 'Tu pedido está vacío.',
            'items.min' => 'Tu pedido está vacío.',
            'items.max' => 'Son demasiados platos para un solo pedido.',

            'items.*.quantity.required' => 'Falta la cantidad.',
            'items.*.quantity.min' => 'La cantidad tiene que ser al menos 1.',

            'notes.max' => 'La nota es demasiado larga.',

            'idempotency_key.required' => 'Falta la clave del pedido.',
        ];
    }
}
