@extends('layouts.panel')

@section('title', 'Tablero')

@section('content')

    <h1 class="text-2xl font-extrabold">Tablero</h1>
    <p class="mt-1 text-sm text-navy/60">Cómo está ToroGo ahora mismo.</p>

    {{-- ------------------------- Los números del día ------------------------- --}}

    <h2 class="mt-8 text-xs font-bold uppercase tracking-wide text-navy/50">Hoy</h2>

    <div class="mt-3 grid gap-4 sm:grid-cols-3">

        <div class="rounded-2xl bg-teal p-5 text-white">
            <div class="text-sm font-semibold text-white/80">Pedidos en curso</div>
            <div class="mt-1 text-4xl font-extrabold">{{ $activeOrders }}</div>
            <div class="mt-1 text-xs text-white/70">Los que todavía no terminaron</div>
        </div>

        <div class="rounded-2xl bg-white p-5 shadow-sm">
            <div class="text-sm font-semibold text-navy/60">Pedidos de hoy</div>
            <div class="mt-1 text-4xl font-extrabold">{{ $todayOrders }}</div>
            <div class="mt-1 text-xs text-navy/50">Desde las 00:00</div>
        </div>

        <div class="rounded-2xl bg-white p-5 shadow-sm">
            <div class="text-sm font-semibold text-navy/60">Vendido hoy</div>
            <div class="mt-1 text-4xl font-extrabold">${{ $todaySales }}</div>
            <div class="mt-1 text-xs text-navy/50">Suma de los pedidos de hoy</div>
        </div>
    </div>

    {{-- --------------------------- Lo que hay vivo --------------------------- --}}

    <h2 class="mt-8 text-xs font-bold uppercase tracking-wide text-navy/50">El negocio</h2>

    <div class="mt-3 grid gap-4 sm:grid-cols-3">

        <div class="rounded-2xl bg-white p-5 shadow-sm">
            <div class="text-sm font-semibold text-navy/60">Restaurantes</div>
            <div class="mt-1 text-3xl font-extrabold">{{ $restaurants }}</div>
            <div class="mt-1 text-xs text-navy/50">
                {{ $openRestaurants }} abiertos ahora
            </div>
        </div>

        <div class="rounded-2xl bg-white p-5 shadow-sm">
            <div class="text-sm font-semibold text-navy/60">Motorizados</div>
            <div class="mt-1 text-3xl font-extrabold">{{ $couriers }}</div>
            <div class="mt-1 text-xs text-navy/50">
                {{ $availableCouriers }} disponibles ahora
            </div>
        </div>

        <div class="rounded-2xl bg-white p-5 shadow-sm">
            <div class="text-sm font-semibold text-navy/60">Clientes</div>
            <div class="mt-1 text-3xl font-extrabold">{{ $clients }}</div>
            <div class="mt-1 text-xs text-navy/50">Cuentas registradas</div>
        </div>
    </div>

    {{-- ------------------------ La grafica de la semana ------------------------ --}}

    <h2 class="mt-8 text-xs font-bold uppercase tracking-wide text-navy/50">Últimos 7 días</h2>

    <div class="mt-3 rounded-2xl bg-white p-6 shadow-sm">
        {{--
            Barras hechas con CSS, sin libreria de graficos: la barra mas alta
            ocupa el 100% y las demas se calculan contra esa (ver
            DashboardController::lastSevenDays).
        --}}
        <div class="flex h-40 items-end gap-2">
            @foreach ($days as $day)
                <div class="flex h-full flex-1 flex-col items-center justify-end gap-1">
                    <div class="text-xs font-semibold text-navy/70">${{ $day['sales'] }}</div>

                    <div class="flex w-full flex-1 items-end">
                        <div class="w-full rounded-t-lg bg-teal transition-all"
                             style="height: {{ $day['percent'] }}%"
                             title="{{ $day['orders'] }} pedidos"></div>
                    </div>

                    <div class="text-xs text-navy/50">{{ $day['label'] }}</div>
                </div>
            @endforeach
        </div>

        <p class="mt-4 text-xs text-navy/50">
            Es la venta de cada día, <strong>sin contar los pedidos cancelados</strong>.
            Pasá el mouse por una barra para ver cuántos pedidos fueron.
        </p>
    </div>

    {{--
        Lo que TODAVIA no está, dicho de frente en vez de dejar el menú vacío:
        así el panel no miente sobre lo que puede hacer.
    --}}
    <div class="mt-8 rounded-2xl bg-yellow/20 p-5">
        <div class="text-sm font-bold text-navy">Lo que falta en el panel</div>
        <ul class="mt-2 space-y-1 text-sm text-navy/70">
            <li>· Notificaciones con la app cerrada (FCM), para el motorizado.</li>
            <li>· El historial y las ganancias del motorizado.</li>
            <li>· La foto de licencia y DUI de cada motorizado (la biblia la pide).</li>
        </ul>
        <p class="mt-3 text-xs text-navy/50">
            El panel ya está completo: restaurantes, motorizados, pedidos, clientes
            y las tarifas se manejan desde acá, sin tocar la base a mano.
        </p>
    </div>

@endsection
