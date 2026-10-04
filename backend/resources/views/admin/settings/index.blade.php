@extends('layouts.panel')

@section('title', 'Configuración')

@section('content')

    <div>
        <h1 class="text-2xl font-extrabold">Configuración</h1>
        <p class="mt-1 text-sm text-navy/60">Las tarifas de envío y la comisión de ToroGo.</p>
    </div>

    {{--
        Este aviso no es decoracion: es la diferencia entre cambiar un precio
        hacia adelante y reescribir el pasado. Cada pedido guarda una copia de lo
        que costo, asi que el historial no se toca.
    --}}
    <div class="mt-6 rounded-2xl bg-yellow/20 p-5 text-sm text-navy/70">
        <span class="font-bold text-navy">Ojo con esto:</span>
        cambiar una tarifa afecta a los pedidos <strong>nuevos</strong>. Los pedidos ya hechos
        guardan una copia de lo que costaron ese día, así que sus cuentas y el historial no cambian.
    </div>

    @foreach ($zones as $zone)
        @php
            $puntos = count($zone->polygon['coordinates'][0] ?? []);
        @endphp

        <div class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
            <div class="flex flex-wrap items-center justify-between gap-3">
                <div>
                    <h2 class="text-lg font-bold">{{ $zone->name }}</h2>
                    <p class="mt-1 text-xs text-navy/60">
                        Zona de cobertura con <strong>{{ $puntos }} puntos</strong> ·
                        {{ $zone->is_active ? 'activa' : 'inactiva' }} ·
                        el cliente paga hoy
                        <strong>${{ $totalToCustomer->get($zone->id, '0.00') }}</strong>
                    </p>
                </div>
            </div>

            <form method="POST" action="{{ route('admin.settings.update', $zone) }}"
                  class="mt-5 flex flex-wrap items-end gap-4 border-t border-navy/10 pt-5">
                @csrf

                <div>
                    <label for="courier_fee" class="mb-1 block text-sm font-semibold">
                        Para el motorizado
                    </label>
                    <input id="courier_fee" name="courier_fee" type="number" step="0.01" min="0"
                           value="{{ old('courier_fee', $zone->courier_fee) }}"
                           class="w-36 rounded-xl border border-navy/15 px-4 py-2.5 outline-none transition focus:border-teal focus:ring-2 focus:ring-teal/20">
                    @error('courier_fee')
                        <p class="mt-1 text-xs font-medium text-coral">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="platform_fee" class="mb-1 block text-sm font-semibold">
                        Para ToroGo
                    </label>
                    <input id="platform_fee" name="platform_fee" type="number" step="0.01" min="0"
                           value="{{ old('platform_fee', $zone->platform_fee) }}"
                           class="w-36 rounded-xl border border-navy/15 px-4 py-2.5 outline-none transition focus:border-teal focus:ring-2 focus:ring-teal/20">
                    @error('platform_fee')
                        <p class="mt-1 text-xs font-medium text-coral">{{ $message }}</p>
                    @enderror
                </div>

                <button type="submit"
                        class="rounded-xl bg-teal px-6 py-2.5 font-bold text-white transition hover:bg-teal-deep">
                    Guardar tarifas
                </button>
            </form>
        </div>
    @endforeach

    {{--
        Lo que NO se edita aca, dicho de frente. Si no se explicara, alguien
        pasaria un buen rato buscando donde mover el mapa de la zona.
    --}}
    <div class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        <h2 class="text-sm font-bold">Lo que no se cambia desde acá</h2>
        <ul class="mt-2 space-y-1 text-sm text-navy/70">
            <li>
                · <strong>El mapa de la zona</strong>: son los {{ count($zones->first()?->polygon['coordinates'][0] ?? []) }}
                puntos que salen del archivo <code class="rounded bg-background px-1">zonas-de-envio.kml</code>.
                Se cambia ahí y se vuelve a correr el seeder, no escribiendo coordenadas a mano.
            </li>
            <li>
                · <strong>Los precios del menú</strong>: los pone cada restaurante desde su app, que es
                quien conoce su costo.
            </li>
        </ul>
    </div>

@endsection
