@extends('layouts.panel')
@section('title', 'Tablero')
@section('content')
    <div class="admin-section-header"><div><span class="admin-overline">VISTA GENERAL</span><h1>Todo en movimiento.</h1><p>Así está ToroGo hoy. Cada entrega cuenta.</p></div><a class="admin-button admin-button-secondary" href="{{ route('admin.orders.index') }}">Ver pedidos</a></div>
    <div class="admin-dashboard-stats">
        <div class="admin-stat admin-stat-featured"><span>Pedidos en curso</span><strong>{{ $activeOrders }}</strong><small>Entregas que todavía no terminaron</small></div>
        <div class="admin-stat"><span>Pedidos de hoy</span><strong>{{ $todayOrders }}</strong><small>Desde las 00:00 de El Salvador</small></div>
        <div class="admin-stat"><span>Vendido hoy</span><strong>${{ $todaySales }}</strong><small>Sin cancelados ni rechazados</small></div>
    </div>
    <div class="admin-dashboard-grid">
        <section class="admin-panel" aria-labelledby="admin-sales-title">
            <div class="admin-panel-heading"><h2 id="admin-sales-title">Ventas de la semana</h2><span class="text-xs text-navy/60">Últimos 7 días</span></div>
            <div class="admin-chart">
                <div class="admin-chart-bars" role="img" aria-label="Ventas de los últimos siete días. Los importes se muestran sobre cada barra.">
                    @foreach($days as $day)
                        <div class="admin-chart-day"><strong>${{ $day['sales'] }}</strong><div class="admin-chart-track"><div class="admin-chart-bar" style="height: {{ $day['percent'] }}%" title="{{ $day['orders'] }} pedidos"></div></div><small>{{ $day['label'] }}</small></div>
                    @endforeach
                </div>
                <p class="admin-chart-caption">Ventas por día, sin contar pedidos cancelados ni rechazados.</p>
            </div>
        </section>
        <section class="admin-panel" aria-labelledby="admin-operation-title">
            <div class="admin-panel-heading"><h2 id="admin-operation-title">Tu operación</h2></div>
            <a class="admin-business-row" href="{{ route('admin.restaurants.index') }}"><div><span>Restaurantes</span><small>{{ $openRestaurants }} abiertos ahora</small></div><strong>{{ $restaurants }}</strong></a>
            <a class="admin-business-row" href="{{ route('admin.couriers.index') }}"><div><span>Motorizados</span><small>{{ $availableCouriers }} disponibles ahora</small></div><strong>{{ $couriers }}</strong></a>
            <a class="admin-business-row" href="{{ route('admin.customers.index') }}"><div><span>Clientes</span><small>Cuentas registradas</small></div><strong>{{ $clients }}</strong></a>
        </section>
    </div>
    <section class="admin-panel mt-6" aria-labelledby="admin-recent-title">
        <div class="admin-panel-heading"><h2 id="admin-recent-title">Últimos pedidos</h2><a href="{{ route('admin.orders.index') }}">Ver todos</a></div>
        <table class="text-left text-sm"><thead><tr><th class="p-4">Pedido</th><th class="p-4">Restaurante</th><th class="p-4">Estado</th><th class="p-4 text-right">Total</th><th class="p-4">Detalle</th></tr></thead><tbody>
            @forelse($recentOrders as $order)
                <tr class="border-t border-navy/10"><td class="p-4 font-semibold">#{{ $order->id }}</td><td class="p-4">{{ $order->restaurant?->name ?? '—' }}</td><td class="p-4">{{ $order->status->label() }}</td><td class="p-4 text-right">${{ $order->total }}</td><td class="p-4"><a class="text-teal-deep font-semibold" href="{{ route('admin.orders.show', $order) }}">Ver pedido</a></td></tr>
            @empty
                <tr><td colspan="5" class="p-6 admin-table-empty">Todavía no hay pedidos. Cuando llegue el primero, aparecerá aquí.</td></tr>
            @endforelse
        </tbody></table>
    </section>
@endsection
