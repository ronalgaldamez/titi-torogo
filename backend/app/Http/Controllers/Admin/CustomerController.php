<?php

namespace App\Http\Controllers\Admin;

use App\Enums\OrderStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\User;
use App\Support\Money;
use Illuminate\Support\Collection;
use Illuminate\View\View;

/**
 * Los clientes, vistos desde el administrador: la biblia lo pide como
 * "Lista de clientes".
 *
 * NO HAY ACTIVAR/DESACTIVAR aca, y es a proposito: la biblia pide una LISTA. Un
 * cliente que no puede entrar a la app no tiene a quien reclamarle (no hay un
 * local que lo atienda ni un motorizado que le responda), asi que la decision
 * de bloquear a alguien no se toma desde una pantalla. Si algun dia hace falta,
 * se agrega con su propia conversacion.
 *
 * Lo que SI hace es lo que se necesita cuando un cliente llama: ver quien es,
 * donde vive y que pidio antes.
 */
class CustomerController extends Controller
{
    /**
     * GET /admin/clientes
     */
    public function index(): View
    {
        $customers = User::query()
            ->where('role', UserRole::Client->value)
            // withCount hace un COUNT en la misma consulta: sin esto serian 25
            // consultas mas, una por fila de la tabla.
            ->withCount('orders')
            ->orderBy('name')
            ->paginate(25);

        return view('admin.customers.index', [
            'customers' => $customers,
            'spent' => $this->spentByCustomer($customers->getCollection()),
        ]);
    }

    /**
     * GET /admin/clientes/{customer}
     */
    public function show(User $customer): View
    {
        // Un id que no sea de cliente da 404, igual que en motorizados: sin
        // esto, /admin/clientes/1 mostraria la cuenta del administrador.
        abort_unless($customer->hasRole(UserRole::Client), 404);

        $customer->load('addresses');

        $orders = $customer->orders()
            ->with('restaurant:id,name')
            ->orderByDesc('id')
            ->paginate(15);

        return view('admin.customers.show', [
            'customer' => $customer,
            'orders' => $orders,
            'spent' => $this->spentByCustomer(new Collection([$customer]))->get($customer->id, '0.00'),
        ]);
    }

    /**
     * Cuanto lleva gastado cada cliente, sumado con bcmath.
     *
     * POR QUE NO SE USA withSum: el dinero en este proyecto NUNCA pasa por
     * float, y una suma que vuelve como float puede traer ese centavo fantasma
     * que despues no cuadra. Se traen los totales y se suman con Money, que usa
     * bcadd.
     *
     * Solo se cuentan los pedidos ENTREGADOS: es la plata que de verdad entro.
     * Un pedido cancelado o rechazado no es gasto de nadie.
     *
     * @param  Collection<int, User>  $customers
     * @return Collection<int, string>
     */
    private function spentByCustomer(Collection $customers): Collection
    {
        if ($customers->isEmpty()) {
            return new Collection;
        }

        return Order::query()
            ->whereIn('user_id', $customers->pluck('id'))
            ->where('status', OrderStatus::Delivered->value)
            ->get(['user_id', 'total'])
            ->groupBy('user_id')
            ->map(fn (Collection $orders): string => Money::add(
                ...$orders->pluck('total')->all(),
            ));
    }
}
