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

        return view('admin.dashboard', [
            'activeOrders' => $activeOrders,
            'todayOrders' => $today->count(),
            'todaySales' => Money::add(...$today->pluck('total')->all()),

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
}
