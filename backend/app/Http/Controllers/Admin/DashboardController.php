<?php

namespace App\Http\Controllers\Admin;

use App\Enums\OrderStatus;
use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\Restaurant;
use App\Models\User;
use App\Support\Money;
use Illuminate\View\View;

/**
 * El resumen del panel: pedidos activos, restaurantes y motorizados.
 *
 * Es lo que la biblia pide como "Dashboard: Resumen general" del perfil
 * administrador.
 *
 * Los numeros se cuentan EN EL MOMENTO de abrir la pagina. No hay cache a
 * proposito: con el volumen de Tejutla contar es instantaneo, y un numero viejo
 * en un panel de control es peor que no tener el numero.
 */
class DashboardController extends Controller
{
    public function index(): View
    {
        $activeOrders = Order::query()
            ->whereNotIn('status', OrderStatus::finalValues())
            ->count();

        // Los pedidos de HOY, para el resumen del dia. Se traen los modelos y no
        // se usa sum() de SQL porque el dinero se suma con bcmath, como en todo
        // el proyecto: sum() devolveria un float y ese centavo fantasma
        // terminaria en el panel.
        $today = Order::query()
            ->whereDate('created_at', today())
            ->get();

        // "Vendido" NO cuenta lo cancelado ni lo rechazado: esa plata nunca
        // entro. Antes se sumaba todo, y un pedido cancelado inflaba el numero
        // del dia, que es justo el numero que se mira para saber como fue.
        $sold = $today->reject(
            fn (Order $order): bool => in_array($order->status, [
                OrderStatus::Cancelled,
                OrderStatus::Rejected,
            ], true),
        );

        return view('admin.dashboard', [
            'activeOrders' => $activeOrders,
            'todayOrders' => $today->count(),
            'todaySales' => Money::add(...$sold->pluck('total')->all()),
            'days' => $this->lastSevenDays(),

            'restaurants' => Restaurant::query()->count(),
            'openRestaurants' => Restaurant::query()
                ->where('is_open', true)
                ->count(),

            'couriers' => User::query()
                ->where('role', UserRole::Courier->value)
                ->count(),
            'availableCouriers' => User::query()
                ->where('role', UserRole::Courier->value)
                ->where('is_available', true)
                ->count(),

            'clients' => User::query()
                ->where('role', UserRole::Client->value)
                ->count(),
        ]);
    }

    /**
     * Los ultimos 7 dias, para la grafica del tablero.
     *
     * La biblia pide "graficas basicas del dia" y se hacen con barras de CSS, a
     * proposito: meter una libreria de graficos (y su JavaScript) para siete
     * barritas es cargar medio megabyte por nada. Si algun dia hacen falta
     * graficos de verdad, se cambia esta funcion y la vista, nada mas.
     *
     * Cada dia trae su VENTA (sin contar cancelados, igual que "vendido hoy") y
     * el alto de la barra ya calculado, para que la vista no haga cuentas.
     *
     * @return array<int, array{label: string, orders: int, sales: string, percent: int}>
     */
    private function lastSevenDays(): array
    {
        $days = [];

        foreach (range(6, 0) as $ago) {
            $date = today()->subDays($ago);

            $orders = Order::query()
                ->whereDate('created_at', $date)
                ->whereNotIn('status', [
                    OrderStatus::Cancelled->value,
                    OrderStatus::Rejected->value,
                ])
                ->get(['total']);

            $days[] = [
                // Formato corto numerico: "lun 29" se lee mejor, pero depende
                // del idioma del sistema. "29/09" se entiende siempre.
                'label' => $date->format('d/m'),
                'orders' => $orders->count(),
                'sales' => Money::add(...$orders->pluck('total')->all()),
            ];
        }

        // El alto de cada barra, en porcentaje del dia mas alto. Se calcula con
        // bcmath y no con floats, por la misma regla de siempre.
        $max = '0.00';

        foreach ($days as $day) {
            if (bccomp($day['sales'], $max, 2) === 1) {
                $max = $day['sales'];
            }
        }

        foreach ($days as $index => $day) {
            $percent = 0;

            if (bccomp($max, '0', 2) === 1 && bccomp($day['sales'], '0', 2) === 1) {
                // Un minimo de 4% para que un dia con venta chica se VEA: una
                // barra de un pixel parece un error de dibujo.
                $percent = max(4, (int) bcdiv(bcmul($day['sales'], '100', 2), $max, 0));
            }

            $days[$index]['percent'] = $percent;
        }

        return $days;
    }
}
