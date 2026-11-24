<?php

namespace App\Http\Requests;

use App\Enums\OrderStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Valida el cambio de estado de un pedido.
 *
 * Aqui solo se valida que el estado EXISTA. Si la transicion es legal, y si
 * le toca a quien la pide, se verifica en el controlador con la maquina de
 * estados del enum.
 *
 * Son tres preguntas distintas y conviene no mezclarlas: "¿existe ese
 * estado?", "¿se puede llegar ahi desde donde esta?" y "¿vos sos quien puede
 * hacerlo?". Si se juntaran en la validacion, todos los errores saldrian con
 * el mismo mensaje y no se entenderia cual de las tres fallo.
 */
class UpdateOrderStatusRequest extends FormRequest
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
            'status' => ['required', Rule::enum(OrderStatus::class)],
            'pickup_pin' => ['sometimes', 'string', 'regex:/^[0-9]{6}$/'],
            'delivery_pin' => ['sometimes', 'string', 'regex:/^[0-9]{6}$/'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'status.required' => 'Falta el estado nuevo.',
            'status.enum' => 'Ese estado no existe.',
            'pickup_pin.string' => 'Ingresá el PIN de recogida de 6 dígitos.',
            'delivery_pin.string' => 'Ingresá el PIN de entrega de 6 dígitos.',
            'pickup_pin.regex' => 'El PIN de recogida debe tener 6 dígitos.',
            'delivery_pin.regex' => 'El PIN de entrega debe tener 6 dígitos.',
        ];
    }
}
