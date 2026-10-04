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

    {{--
        Lo que TODAVIA no está, dicho de frente en vez de dejar el menú vacío:
        así el panel no miente sobre lo que puede hacer.
    --}}
    <div class="mt-8 rounded-2xl bg-yellow/20 p-5">
        <div class="text-sm font-bold text-navy">Lo que falta en el panel</div>
        <ul class="mt-2 space-y-1 text-sm text-navy/70">
            <li>· Pedidos: ver todos y poder cancelar o reasignar.</li>
            <li>· Clientes, y la configuración de tarifas y comisiones.</li>
            <li>· Gráficas del día (los números ya están, falta el dibujo).</li>
        </ul>
        <p class="mt-3 text-xs text-navy/50">
            Los restaurantes y los motorizados ya se manejan desde
            <a href="{{ route('admin.restaurants.index') }}" class="font-semibold text-teal-deep underline">
                Restaurantes
            </a>
            y
            <a href="{{ route('admin.couriers.index') }}" class="font-semibold text-teal-deep underline">
                Motorizados
            </a>, sin tocar la base a mano.
        </p>
    </div>

@endsection
