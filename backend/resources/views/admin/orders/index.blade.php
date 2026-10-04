@extends('layouts.panel')

@section('title', 'Pedidos')

@section('content')

    <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
            <h1 class="text-2xl font-extrabold">Pedidos</h1>
            <p class="mt-1 text-sm text-navy/60">Todos los pedidos de ToroGo, no los de un solo local.</p>
        </div>
    </div>

    {{-- Los números primero: es lo que se mira al entrar. --}}
    <div class="mt-6 grid gap-4 sm:grid-cols-4">
        @php
            $tarjetas = [
                ['label' => 'En curso', 'value' => $counters['activos'], 'color' => 'bg-teal text-white'],
                ['label' => 'De hoy', 'value' => $counters['hoy'], 'color' => 'bg-white'],
                ['label' => 'Entregados', 'value' => $counters['entregados'], 'color' => 'bg-white'],
                ['label' => 'Cancelados', 'value' => $counters['cancelados'], 'color' => 'bg-white'],
            ];
        @endphp

        @foreach ($tarjetas as $tarjeta)
            <div class="rounded-2xl {{ $tarjeta['color'] }} p-5 shadow-sm">
                <div class="text-sm font-semibold {{ $tarjeta['color'] === 'bg-white' ? 'text-navy/60' : 'text-white/80' }}">
                    {{ $tarjeta['label'] }}
                </div>
                <div class="mt-1 text-3xl font-extrabold">{{ $tarjeta['value'] }}</div>
            </div>
        @endforeach
    </div>

    {{-- Filtros. Todo por GET: la dirección se puede recargar o compartir. --}}
    <form method="GET" action="{{ route('admin.orders.index') }}"
          class="mt-6 flex flex-wrap items-end gap-3 rounded-2xl bg-white p-4 shadow-sm">

        <div>
            <label for="estado" class="mb-1 block text-xs font-semibold text-navy/60">Estado</label>
            <select id="estado" name="estado"
                    class="rounded-xl border border-navy/15 bg-white px-4 py-2.5 outline-none focus:border-teal">
                @foreach (['activos' => 'En curso', 'entregados' => 'Entregados', 'cancelados' => 'Cancelados', 'todos' => 'Todos'] as $value => $label)
                    <option value="{{ $value }}" @selected($status === $value)>{{ $label }}</option>
                @endforeach
            </select>
        </div>

        <div>
            <label for="restaurante" class="mb-1 block text-xs font-semibold text-navy/60">Restaurante</label>
            <select id="restaurante" name="restaurante"
                    class="rounded-xl border border-navy/15 bg-white px-4 py-2.5 outline-none focus:border-teal">
                <option value="">Todos</option>
                @foreach ($restaurants as $restaurant)
                    <option value="{{ $restaurant->id }}" @selected((string) $restaurantId === (string) $restaurant->id)>
                        {{ $restaurant->name }}
                    </option>
                @endforeach
            </select>
        </div>

        <div>
            <label for="buscar" class="mb-1 block text-xs font-semibold text-navy/60">Número</label>
            <input id="buscar" name="buscar" value="{{ $search }}" placeholder="Ej: 47" inputmode="numeric"
                   class="w-28 rounded-xl border border-navy/15 bg-white px-4 py-2.5 outline-none focus:border-teal">
        </div>

        <button type="submit"
                class="rounded-xl bg-teal px-5 py-2.5 font-semibold text-white transition hover:bg-teal-deep">
            Filtrar
        </button>

        <a href="{{ route('admin.orders.index') }}"
           class="rounded-xl px-3 py-2.5 text-sm font-medium text-navy/60 hover:text-navy">
            Limpiar
        </a>
    </form>

    @if ($orders->isEmpty())
        <div class="mt-6 rounded-2xl bg-white p-8 text-center shadow-sm">
            <p class="text-sm text-navy/60">No hay pedidos que coincidan con esos filtros.</p>
        </div>
    @else
        <div class="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm">
            <table class="w-full text-left text-sm">
                <thead class="bg-teal-soft text-xs uppercase tracking-wide text-teal-deep">
                    <tr>
                        <th class="px-4 py-3 font-bold">#</th>
                        <th class="px-4 py-3 font-bold">Cuándo</th>
                        <th class="px-4 py-3 font-bold">Restaurante</th>
                        <th class="px-4 py-3 font-bold">Cliente</th>
                        <th class="px-4 py-3 font-bold">Motorizado</th>
                        <th class="px-4 py-3 font-bold">Estado</th>
                        <th class="px-4 py-3 font-bold text-right">Total</th>
                        <th class="px-4 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($orders as $order)
                        <tr class="border-t border-navy/5">
                            <td class="px-4 py-3 font-bold text-navy">{{ $order->id }}</td>

                            <td class="px-4 py-3 text-xs text-navy/70">
                                {{ $order->created_at->format('d/m H:i') }}
                            </td>

                            <td class="px-4 py-3 text-navy/80">
                                {{ $order->restaurant?->name ?? '—' }}
                            </td>

                            <td class="px-4 py-3 text-navy/80">
                                {{ $order->user?->name ?? '—' }}
                            </td>

                            <td class="px-4 py-3 text-navy/80">
                                {{ $order->courier?->name ?? '—' }}
                            </td>

                            {{-- El color dice de un vistazo si esta vivo, bien o cortado. --}}
                            <td class="px-4 py-3">
                                @php
                                    $color = match ($order->status) {
                                        \App\Enums\OrderStatus::Delivered => 'bg-mint/20 text-teal-deep',
                                        \App\Enums\OrderStatus::Cancelled,
                                        \App\Enums\OrderStatus::Rejected => 'bg-coral/15 text-coral',
                                        default => 'bg-teal-soft text-teal-deep',
                                    };
                                @endphp
                                <span class="rounded-full {{ $color }} px-3 py-1 text-xs font-bold">
                                    {{ $order->status->label() }}
                                </span>
                            </td>

                            <td class="px-4 py-3 text-right font-semibold text-navy">${{ $order->total }}</td>

                            <td class="px-4 py-3 text-right">
                                <a href="{{ route('admin.orders.show', $order) }}"
                                   class="rounded-full bg-teal-soft px-4 py-2 text-xs font-bold text-teal-deep transition hover:bg-teal hover:text-white">
                                    Ver
                                </a>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>

        <div class="mt-4">
            {{ $orders->links() }}
        </div>
    @endif

@endsection
