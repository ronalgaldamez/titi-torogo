<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateAvailabilityRequest;
use App\Http\Requests\UpdateOrderStatusRequest;
use App\Http\Resources\OrderResource;
use App\Http\Resources\UserResource;
use App\Models\Order;
use App\Support\Geometry;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

/**
 * Los pedidos vistos por el motorizado.
 *
 * El motorizado no "tiene" pedidos hasta que los toma: su relacion es
 * courier_id, que arranca en null. Eso es lo que hace que dos motorizados
 * puedan ver la misma lista de disponibles sin pisarse.
 */
class CourierOrderController extends Controller
{
    /**
     * Radio de busqueda por defecto, en kilometros. La biblia dice 5 km.
     */
    private const DEFAULT_RADIUS_KM = 5.0;

    /**
     * PATCH /api/courier/availability
     *
     * "Disponible / No disponible".
     */
    public function updateAvailability(UpdateAvailabilityRequest $request): JsonResponse
    {
        $user = $request->user();

        // El modelo sale de la sesion: 'is_available' no es fillable a
        // proposito, asi que se asigna explicito.
        $user->is_available = $request->validated('is_available');
        $user->save();

        return response()->json([
            'user' => new UserResource($user),
        ]);
    }

    /**
     * GET /api/courier/orders
     *
     * Los pedidos que YO llevo, en curso por defecto. Es la pantalla de
     * tracking activo.
     */
    public function index(Request $request): JsonResponse
    {
        $query = $request->user()->courierOrders()
            ->with(['items', 'restaurant'])
            ->latest();

        $requested = $request->query('status');

        if (is_string($requested) && $requested !== '') {
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
     * GET /api/courier/orders/available?latitude=..&longitude=..
     *
     * Los pedidos listos para recoger y SIN repartidor, a menos de 5 km del
     * motorizado (o del radio que pida), del mas cercano al mas lejano.
     */
    public function available(Request $request): JsonResponse
    {
        $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_km' => ['sometimes', 'numeric', 'min:1', 'max:50'],
        ]);

        $latitude = (float) $request->query('latitude');
        $longitude = (float) $request->query('longitude');

        // La biblia dice "radio configurable, ej: 5 km": el 5 es el default,
        // no una jaula.
        $radius = (float) ($request->query('radius_km') ?? self::DEFAULT_RADIUS_KM);

        $orders = Order::query()
            // "Listo para recoger" y sin repartidor: esas dos condiciones
            // juntas son la definicion de "disponible".
            ->where('status', OrderStatus::Ready->value)
            ->whereNull('courier_id')
            ->with(['items', 'restaurant'])
            ->get();

        // La distancia se mide del MOTORIZADO al RESTAURANTE, no al cliente:
        // es a donde tiene que ir primero.
        foreach ($orders as $order) {
            $order->setAttribute('distance_km', Geometry::distanceKm(
                $latitude,
                $longitude,
                $order->restaurant->latitude,
                $order->restaurant->longitude,
            ));
        }

        // Se filtra en PHP, igual que las zonas del Home. Hoy sobran pedidos
        // para que esto importe; con muchos, se resuelve con PostGIS, que es
        // la misma nota que ya esta en RestaurantController.
        $nearby = $orders
            ->filter(fn (Order $order): bool => $order->distance_km <= $radius)
            ->sortBy('distance_km')
            ->values();

        return response()->json([
            'orders' => OrderResource::collection($nearby),
        ]);
    }

    /**
     * POST /api/courier/orders/{order}/take
     *
     * El motorizado TOMA el pedido. Es la operacion mas delicada del flujo:
     * dos motorizados pueden tocar "tomar" en el mismo segundo.
     */
    public function take(Request $request, int $order): JsonResponse
    {
        // COMPARE-AND-SWAP: el UPDATE solo entra si el pedido TODAVIA esta
        // listo y TODAVIA no tiene repartidor. Las dos condiciones van en el
        // WHERE, o sea que las revisa la base en la misma operacion que
        // escribe.
        //
        // Por eso no hace falta un lock explicito ni un 'if' antes: un if se
        // queda viejo entre que se lee y se escribe, y ahi es donde los dos
        // motorizados ganan. Aca, el que llega segundo afecta 0 filas.
        $taken = Order::query()
            ->where('id', $order)
            ->where('status', OrderStatus::Ready->value)
            ->whereNull('courier_id')
            ->update(['courier_id' => $request->user()->id]);

        if ($taken === 0) {
            throw ValidationException::withMessages([
                'order' => 'Ese pedido ya no está disponible.',
            ]);
        }

        $model = Order::query()
            ->with(['items', 'restaurant'])
            ->findOrFail($order);

        return response()->json([
            'order' => new OrderResource($model),
        ]);
    }

    /**
     * PATCH /api/courier/orders/{order}
     *
     * Recogido y entregado.
     */
    public function updateStatus(UpdateOrderStatusRequest $request, int $order): JsonResponse
    {
        // Sobre la relacion del motorizado: el pedido de otro responde 404.
        $model = $request->user()->courierOrders()->findOrFail($order);

        $status = OrderStatus::from($request->validated('status'));

        // "Aceptado" o "listo para recoger" son del restaurante, aunque la
        // transicion sea legal desde donde esta.
        if (! $status->isCourierAction()) {
            throw ValidationException::withMessages([
                'status' => 'Esa acción no le corresponde al motorizado.',
            ]);
        }

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
