<?php

namespace App\Http\Controllers\Admin;

use App\Enums\OrderStatus;
use App\Enums\UserRole;
use App\Events\OrderUpdated;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

/**
 * Los pedidos vistos desde el administrador: la biblia lo pide como
 * "Lista de todos los pedidos (activos y pasados)" + "Detalle del pedido" +
 * poder "cancelar pedidos y reasignar motorizados manualmente".
 *
 * POR QUE ESTA SECCION ES LA MAS IMPORTANTE DEL PANEL
 *
 * Las otras dos (restaurantes y motorizados) son de alta: se usan una vez cada
 * tanto. Esta se usa cuando algo se TRABAJA a las 8 de la noche — el
 * restaurante se quedo sin gas, el motorizado se pincho, el cliente llamo
 * porque ya no quiere el pedido. Sin esto, el administrador mira la base de
 * datos o no hace nada.
 *
 * OJO CON LO QUE NO HACE, a proposito:
 *
 *   - NO mueve el pedido por el recorrido normal (aceptar, preparar, listo).
 *     Eso es del restaurante y del motorizado; si el administrador pudiera
 *     tocar todo, el historial dejaria de decir quien hizo que.
 *   - Lo unico que hace es CANCELAR (cortar) y REASIGNAR el motorizado, que
 *     son exactamente las dos intervenciones que pide la biblia.
 */
class OrderController extends Controller
{
    /**
     * GET /admin/pedidos
     */
    public function index(Request $request): View
    {
        $status = (string) $request->query('estado', 'activos');
        $restaurantId = $request->query('restaurante');
        $search = trim((string) $request->query('buscar'));

        $orders = Order::query()
            // with() para no hacer una consulta por fila al pintar la tabla.
            // Se piden solo las columnas que se muestran.
            ->with(['restaurant:id,name', 'courier:id,name', 'user:id,name'])
            ->when(
                $status === 'activos',
                fn ($query) => $query->whereNotIn('status', OrderStatus::finalValues()),
            )
            ->when(
                $status === 'entregados',
                fn ($query) => $query->where('status', OrderStatus::Delivered->value),
            )
            // "cancelados" incluye los rechazados: para el administrador son
            // lo mismo (pedidos que no llegaron a entregarse) y es la lista
            // que mira cuando quiere entender que se cayo.
            ->when(
                $status === 'cancelados',
                fn ($query) => $query->whereIn('status', [
                    OrderStatus::Cancelled->value,
                    OrderStatus::Rejected->value,
                ]),
            )
            ->when(
                $restaurantId !== null && $restaurantId !== '',
                fn ($query) => $query->where('restaurant_id', (int) $restaurantId),
            )
            // El buscador es por NUMERO de pedido: es lo unico que se dicta por
            // telefono ("el pedido 47"). Si escriben otra cosa, no se filtra
            // nada en vez de devolver una lista vacia que confunde.
            ->when(
                $search !== '' && ctype_digit($search),
                fn ($query) => $query->where('id', (int) $search),
            )
            ->orderByDesc('id')
            ->paginate(25)
            ->withQueryString();

        return view('admin.orders.index', [
            'orders' => $orders,
            'status' => $status,
            'restaurantId' => $restaurantId,
            'search' => $search,
            'restaurants' => $this->restaurantsForFilter(),
            'counters' => $this->counters(),
        ]);
    }

    /**
     * GET /admin/pedidos/{order}
     */
    public function show(Order $order): View
    {
        $order->load(['items', 'restaurant', 'courier', 'user', 'address']);

        return view('admin.orders.show', [
            'order' => $order,
            'couriers' => $this->couriersForAssignment(),
        ]);
    }

    /**
     * POST /admin/pedidos/{order}/cancelar
     */
    public function cancel(Order $order): RedirectResponse
    {
        return DB::transaction(function () use ($order) {
            $order = Order::query()->lockForUpdate()->findOrFail($order->id);
            if ($order->status === OrderStatus::Cancelled) {
                return back()->with('status', "El pedido #{$order->id} ya está cancelado.");
            }
            if ($order->status->isFinal()) {
                return back()->with('error', "El pedido #{$order->id} ya está cerrado ({$order->status->label()}).");
            }

            // El estado viejo se guarda ANTES: moveTo lo pisa, y el evento lo
            // necesita para que las apps sepan de donde venia el cambio.
            $previous = $order->status->value;

            if (! $order->moveTo(OrderStatus::Cancelled)) {
                return back()->with('error', 'Ese pedido no se puede cancelar desde su estado actual.');
            }

            $order->save();

            // Se avisa AL INSTANTE: el cliente lo ve en su seguimiento sin
            // refrescar, con el mismo canal de tiempo real que usan las apps.
            DB::afterCommit(fn () => OrderUpdated::announce($order, $previous));

            return back()->with(
                'status',
                "El pedido #{$order->id} quedó cancelado. El cliente ya lo ve en su app.",
            );
        });
    }

    /**
     * POST /admin/pedidos/{order}/motorizado
     *
     * Le pone un motorizado a mano.
     */
    public function assignCourier(Request $request, Order $order): RedirectResponse
    {
        return DB::transaction(function () use ($request, $order) {
            $order = Order::query()->lockForUpdate()->findOrFail($order->id);
            // Asignar solo tiene sentido cuando el pedido ya esta listo para
            // recoger o yendo: antes de eso todavia no hay nada que repartir, y
            // ademas el motorizado no lo veria en su lista de disponibles.
            if (! in_array($order->status, [OrderStatus::Ready, OrderStatus::PickedUp], true)) {
                return back()->with(
                    'error',
                    'Solo se le puede asignar un motorizado a un pedido listo para recoger o en camino.',
                );
            }

            $data = $request->validate(
                ['courier_id' => ['required', 'integer', 'exists:users,id']],
                ['courier_id.required' => 'Elegí un motorizado.'],
            );

            // Se busca entre los motorizados ACTIVOS: si se dio de baja, no puede
            // recibir pedidos aunque alguien lo elija desde una pantalla vieja.
            $courier = User::query()
                ->where('role', UserRole::Courier->value)
                ->where('is_active', true)
                ->find($data['courier_id']);

            if ($courier === null) {
                return back()->with('error', 'Ese motorizado no está activo.');
            }

            if ($order->courier_id === $courier->id) {
                return back()->with('status', 'Ese motorizado ya tiene el pedido asignado.');
            }
            $previous = $order->status->value;

            $order->courier_id = $courier->id;
            $order->save();

            DB::afterCommit(fn () => OrderUpdated::announce($order, $previous));

            return back()->with(
                'status',
                "El pedido #{$order->id} quedó asignado a {$courier->name}.",
            );
        });
    }

    /**
     * POST /admin/pedidos/{order}/liberar
     *
     * Le quita el motorizado y lo devuelve a la lista de disponibles.
     */
    public function releaseCourier(Order $order): RedirectResponse
    {
        return DB::transaction(function () use ($order) {
            $order = Order::query()->lockForUpdate()->findOrFail($order->id);
            if ($order->status !== OrderStatus::Ready) {
                return back()->with('error', 'Solo se puede liberar un pedido listo para recoger.');
            }
            if ($order->courier_id === null) {
                return back()->with('status', 'Ese pedido ya está libre.');
            }

            $previous = $order->status->value;
            $name = $order->courier?->name ?? 'el motorizado';

            $order->courier_id = null;
            $order->save();

            DB::afterCommit(fn () => OrderUpdated::announce($order, $previous));

            return back()->with(
                'status',
                "El pedido #{$order->id} volvió a la lista de disponibles (se lo quitamos a {$name}).",
            );
        });
    }

    /**
     * Los numeros de arriba de la lista: es lo primero que se mira al abrir.
     *
     * @return array<string, int>
     */
    private function counters(): array
    {
        return [
            'activos' => Order::query()
                ->whereNotIn('status', OrderStatus::finalValues())
                ->count(),
            'hoy' => Order::query()->whereDate('created_at', today())->count(),
            'entregados' => Order::query()
                ->where('status', OrderStatus::Delivered->value)
                ->count(),
            'cancelados' => Order::query()
                ->whereIn('status', [
                    OrderStatus::Cancelled->value,
                    OrderStatus::Rejected->value,
                ])
                ->count(),
        ];
    }

    /**
     * Los restaurantes para el filtro, con los que tienen pedidos primero.
     *
     * @return Collection<int, \App\Models\Restaurant>
     */
    private function restaurantsForFilter(): Collection
    {
        return \App\Models\Restaurant::query()
            ->orderBy('name')
            ->get(['id', 'name']);
    }

    /**
     * Los motorizados que se pueden asignar a mano.
     *
     * @return Collection<int, User>
     */
    private function couriersForAssignment(): Collection
    {
        return User::query()
            ->where('role', UserRole::Courier->value)
            ->where('is_active', true)
            ->orderByDesc('is_available')
            ->orderBy('name')
            ->get(['id', 'name', 'phone', 'vehicle', 'is_available']);
    }
}
