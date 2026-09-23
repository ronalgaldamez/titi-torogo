<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateOrderStatusRequest;
use App\Http\Resources\OrderResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Los pedidos vistos por el restaurante.
 *
 * Todo pasa por $request->user()->restaurant (ver EnsureRestaurantAccount), y
 * las consultas salen de la RELACION del restaurante. Asi un pedido de otro
 * restaurante no existe para nosotros: responde 404 y no se filtra nada.
 */
class RestaurantOrderController extends Controller
{
    /**
     * GET /api/restaurant/orders
     *
     * Por defecto devuelve los pedidos EN CURSO, del mas nuevo al mas viejo:
     * es lo que el restaurante necesita tener a la vista mientras trabaja, y
     * el ultimo es el que acaba de sonar.
     *
     * Con ?status=delivered se pide el historial (la biblia lo pide como
     * pantalla aparte).
     */
    public function index(Request $request): JsonResponse
    {
        $restaurant = $request->user()->restaurant;

        $query = $restaurant->orders()
            ->with(['items', 'restaurant'])
            ->latest();

        $requested = $request->query('status');

        if (is_string($requested) && $requested !== '') {
            // tryFrom y no from: from() lanza una excepcion de PHP con un
            // ?status=malo, y eso saldria como error 500 del servidor. Un
            // filtro mal escrito es un error del cliente, y se contesta como
            // tal.
            $status = OrderStatus::tryFrom($requested);

            if ($status === null) {
                throw ValidationException::withMessages([
                    'status' => 'Ese estado no existe.',
                ]);
            }

            $query->where('status', $status->value);
        } else {
            $query->whereNotIn('status', OrderStatus::finalValues());
        }

        return response()->json([
            'orders' => OrderResource::collection($query->get()),
        ]);
    }

    /**
     * PATCH /api/restaurant/orders/{order}
     *
     * Mueve el pedido: aceptar, rechazar, preparando, listo para recoger.
     */
    public function updateStatus(UpdateOrderStatusRequest $request, int $order): JsonResponse
    {
        $restaurant = $request->user()->restaurant;

        // Sobre la relacion: el pedido de otro restaurante responde 404.
        $model = $restaurant->orders()->findOrFail($order);

        $status = OrderStatus::from($request->validated('status'));

        // 1) ¿Le toca al restaurante?
        //    Marcar "entregado" es del motorizado, aunque la transicion sea
        //    legal desde "en camino".
        if (! $status->isRestaurantAction()) {
            throw ValidationException::withMessages([
                'status' => 'Esa acción no le corresponde al restaurante.',
            ]);
        }

        // 2) ¿Se puede llegar ahi desde donde esta?
        //    No se salta de "pendiente" a "listo para recoger": el pedido pasa
        //    por aceptado y preparando, y cada paso queda con su hora.
        //
        //    moveTo devuelve false y NO toca nada cuando la transicion es
        //    ilegal, asi que el mensaje de abajo puede leer el estado viejo.
        if (! $model->moveTo($status)) {
            throw ValidationException::withMessages([
                'status' => "No se puede pasar de «{$model->status->label()}» a «{$status->label()}».",
            ]);
        }

        $model->save();

        return response()->json([
            'order' => new OrderResource($model->load(['items', 'restaurant'])),
        ]);
    }
}
