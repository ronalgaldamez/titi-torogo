<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreOrderRequest;
use App\Http\Resources\OrderResource;
use App\Models\Address;
use App\Models\DeliveryZone;
use App\Models\Order;
use App\Models\Restaurant;
use App\Support\Money;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Los pedidos que hace el cliente.
 *
 * Cualquier cuenta con sesion puede pedir: pedir NO es un privilegio de un
 * perfil. El dueno de un restaurante tambien come, y el motorizado tambien.
 * Lo que si cambia por perfil es lo que cada uno puede VER y HACER con el
 * pedido, y eso vive en los otros controladores.
 */
class OrderController extends Controller
{
    /**
     * POST /api/orders
     *
     * Crea el pedido. Devuelve 201 si lo creo y 200 si era un reintento de un
     * pedido que ya existia.
     */
    public function store(StoreOrderRequest $request): JsonResponse
    {
        $user = $request->user();
        $key = (string) $request->validated('idempotency_key');

        // ¿Ya hay un pedido con esta clave? Entonces esto es un REINTENTO
        // (doble toque, se corto la senal y la app probo de nuevo) y hay que
        // devolver EL MISMO pedido, no crear otro.
        $existing = $user->orders()->where('idempotency_key', $key)->first();

        if ($existing !== null) {
            return $this->ok($existing);
        }

        // La direccion tiene que ser del cliente que esta pidiendo. Con
        // findOrFail sobre la relacion, la de otro usuario da 404 y no se
        // filtra si existe.
        $address = $user->addresses()->findOrFail($request->validated('address_id'));

        $restaurant = $this->openRestaurant((int) $request->validated('restaurant_id'));

        // La zona se calcula con la direccion de ENTREGA, no con la del
        // restaurante: el envio se cobra por donde hay que llegar.
        $zone = $this->zoneFor($address);

        // Las lineas: nombre y precio COPIADOS del catalogo de este
        // restaurante. Lo que mando el cliente solo dice que y cuanto.
        $lines = $this->buildLines($request->validated('items'), $restaurant);

        $prices = $this->prices($zone, $restaurant, $lines);

        try {
            $order = DB::transaction(function () use (
                $user,
                $restaurant,
                $address,
                $request,
                $lines,
                $prices,
                $key,
            ): Order {
                $order = new Order;

                // Campo por campo, como en todo el proyecto.
                $order->user_id = $user->id;
                $order->restaurant_id = $restaurant->id;
                $order->address_id = $address->id;

                // La COPIA de la direccion: es lo que hace que el pedido no
                // cambie si el cliente edita su direccion manana.
                $order->delivery_address = $address->address;
                $order->delivery_reference = $address->reference;
                $order->delivery_latitude = $address->latitude;
                $order->delivery_longitude = $address->longitude;

                $order->status = OrderStatus::Pending;

                // La biblia: pago SOLO en efectivo, sin pasarela.
                $order->payment_method = 'cash';

                $order->notes = $request->validated('notes');
                $order->idempotency_key = $key;

                $order->subtotal = $prices['subtotal'];
                $order->delivery_fee = $prices['delivery_fee'];
                $order->courier_fee = $prices['courier_fee'];
                $order->platform_fee = $prices['platform_fee'];
                $order->total = $prices['total'];

                $order->save();

                // 'order_id' lo pone la relacion, no viene del JSON.
                $order->items()->createMany($lines);

                return $order;
            });
        } catch (UniqueConstraintViolationException) {
            // DOS peticiones identicas al mismo tiempo: las dos pasaron la
            // verificacion de arriba porque el pedido todavia no existia, y
            // las dos intentaron crearlo. El indice unico de la base dejo
            // pasar una sola.
            //
            // Esto es el "locks en base de datos para operaciones criticas"
            // que pide la biblia: el candado es el indice unico, no un if.
            // Un if nunca alcanza cuando dos peticiones corren a la vez.
            $order = $user->orders()->where('idempotency_key', $key)->firstOrFail();

            return $this->ok($order);
        }

        return response()->json([
            'order' => new OrderResource($order->load(['items', 'restaurant', 'courier'])),
        ], 201);
    }

    /**
     * GET /api/orders
     *
     * Los pedidos del cliente que pide.
     *
     *   sin parametros    -> los que estan EN CURSO (es lo que quiere ver
     *                        mientras espera la comida)
     *   ?scope=history    -> los terminados (la pantalla "Mis pedidos")
     *   ?status=delivered -> uno exacto
     */
    public function index(Request $request): JsonResponse
    {
        $query = $request->user()->orders()
            ->with(['items', 'restaurant', 'courier'])
            ->latest();

        $requested = $request->query('status');
        $scope = $request->query('scope');

        if (is_string($requested) && $requested !== '') {
            // tryFrom y no from: un ?status=malo es un error del cliente, no
            // un 500 del servidor.
            $status = OrderStatus::tryFrom($requested);

            if ($status === null) {
                throw ValidationException::withMessages([
                    'status' => 'Ese estado no existe.',
                ]);
            }

            $query->where('status', $status->value);
        } elseif ($scope === 'history') {
            $query->whereIn('status', OrderStatus::finalValues());
        } else {
            $query->whereNotIn('status', OrderStatus::finalValues());
        }

        return response()->json([
            'orders' => OrderResource::collection($query->get()),
        ]);
    }

    /**
     * GET /api/orders/{order}
     *
     * El detalle de UN pedido: la pantalla de seguimiento.
     */
    public function show(Request $request, int $order): JsonResponse
    {
        // Sobre la relacion del cliente: el pedido de OTRO cliente responde
        // 404. No hace falta comparar user_id a mano, y de paso no se filtra
        // si ese pedido existe.
        $model = $request->user()->orders()
            ->with(['items', 'restaurant', 'courier'])
            ->findOrFail($order);

        return response()->json([
            'order' => new OrderResource($model),
        ]);
    }

    /**
     * La respuesta de un pedido que YA existia: 200, no 201, porque no se
     * creo nada ahora.
     */
    private function ok(Order $order): JsonResponse
    {
        return response()->json([
            'order' => new OrderResource($order->load(['items', 'restaurant', 'courier'])),
        ]);
    }

    /**
     * El restaurante, solo si existe, esta activo y esta abierto.
     */
    private function openRestaurant(int $id): Restaurant
    {
        $restaurant = Restaurant::query()
            ->where('is_active', true)
            ->findOrFail($id);

        if (! $restaurant->is_open) {
            throw ValidationException::withMessages([
                'restaurant_id' => 'El restaurante está cerrado en este momento.',
            ]);
        }

        return $restaurant;
    }

    /**
     * La primera zona ACTIVA que cubre la direccion de entrega.
     */
    private function zoneFor(Address $address): DeliveryZone
    {
        $zone = DeliveryZone::query()
            ->where('is_active', true)
            ->get()
            ->first(fn (DeliveryZone $zone) => $zone->contains(
                $address->latitude,
                $address->longitude,
            ));

        if ($zone === null) {
            throw ValidationException::withMessages([
                'address_id' => 'Todavía no llegamos a esa dirección.',
            ]);
        }

        return $zone;
    }

    /**
     * Convierte lo que mando el cliente en lineas con la copia del plato.
     *
     * @param  array<int, array<string, mixed>>  $items
     * @return array<int, array<string, mixed>>
     */
    private function buildLines(array $items, Restaurant $restaurant): array
    {
        // Todos los platos en UNA consulta, y siempre acotados al menu de este
        // restaurante: el id de un plato de otro restaurante simplemente no
        // aparece en el resultado, y abajo se rechaza.
        $products = $restaurant->products()
            ->whereIn('id', array_column($items, 'product_id'))
            ->get()
            ->keyBy('id');

        $lines = [];

        foreach ($items as $item) {
            $product = $products->get((int) $item['product_id']);

            if ($product === null) {
                throw ValidationException::withMessages([
                    'items' => 'Uno de los platos ya no está en el menú de este restaurante.',
                ]);
            }

            if (! $product->is_available) {
                throw ValidationException::withMessages([
                    'items' => "Se acabó: {$product->name}.",
                ]);
            }

            $quantity = (int) $item['quantity'];

            $lines[] = [
                'product_id' => $product->id,

                // LA COPIA. Si el restaurante cambia el precio manana, este
                // pedido sigue diciendo lo que costaba hoy.
                'name' => $product->name,
                'unit_price' => $product->price,

                'quantity' => $quantity,
                'subtotal' => Money::multiply($product->price, $quantity),
            ];
        }

        return $lines;
    }

    /**
     * El desglose del dinero. Todo con bcmath: nunca con '+'.
     *
     * @param  array<int, array<string, mixed>>  $lines
     * @return array<string, string>
     */
    private function prices(
        DeliveryZone $zone,
        Restaurant $restaurant,
        array $lines,
    ): array {
        $subtotal = Money::add(...array_column($lines, 'subtotal'));

        // Lo que paga el cliente: la tarifa propia del restaurante si tiene
        // una (una promocion de envio gratis), o la de la zona.
        $deliveryFee = $restaurant->delivery_fee ?? $zone->deliveryFee();

        return [
            'subtotal' => $subtotal,
            'delivery_fee' => $deliveryFee,

            // OJO: el motorizado y la plataforma cobran SIEMPRE su parte de la
            // zona. Un descuento del restaurante no puede salir del bolsillo
            // del motorizado. Si el restaurante regala el envio, esa
            // diferencia la absorbe el restaurante, y se cuadra en la Fase 2
            // (la de comisiones y pagos).
            'courier_fee' => $zone->courier_fee,
            'platform_fee' => $zone->platform_fee,

            'total' => Money::add($subtotal, $deliveryFee),
        ];
    }
}
