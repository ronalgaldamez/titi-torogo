@extends('layouts.panel')

@section('title', 'Restaurantes')

@section('content')

    <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
            <h1 class="text-2xl font-extrabold">Restaurantes</h1>
            <p class="mt-1 text-sm text-navy/60">
                {{ $restaurants->count() }}
                {{ $restaurants->count() === 1 ? 'local' : 'locales' }}
                @if ($search !== '')
                    que coinciden con «{{ $search }}»
                @endif
            </p>
        </div>

        <a href="{{ route('admin.restaurants.create') }}"
           class="rounded-xl bg-teal px-5 py-3 font-bold text-white transition hover:bg-teal-deep">
            Nuevo restaurante
        </a>
    </div>

    {{-- El buscador es un GET: se puede compartir o recargar la dirección y el
         filtro se mantiene. --}}
    <form method="GET" action="{{ route('admin.restaurants.index') }}" class="mt-6 flex gap-2">
        <input name="buscar" value="{{ $search }}" placeholder="Buscar por nombre…"
               class="w-full max-w-sm rounded-xl border border-navy/15 bg-white px-4 py-2.5 outline-none transition focus:border-teal focus:ring-2 focus:ring-teal/20">
        <button type="submit"
                class="rounded-xl bg-white px-5 py-2.5 font-semibold text-navy shadow-sm transition hover:bg-teal-soft">
            Buscar
        </button>
        @if ($search !== '')
            <a href="{{ route('admin.restaurants.index') }}"
               class="rounded-xl px-4 py-2.5 text-sm font-medium text-navy/60 hover:text-navy">
                Limpiar
            </a>
        @endif
    </form>

    @if ($restaurants->isEmpty())
        <div class="mt-6 rounded-2xl bg-white p-8 text-center shadow-sm">
            <p class="text-sm text-navy/60">
                @if ($search !== '')
                    No hay ningún local que se llame así.
                @else
                    Todavía no hay restaurantes. Empezá con «Nuevo restaurante».
                @endif
            </p>
        </div>
    @else
        <div class="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm">
            <table class="w-full text-left text-sm">
                <thead class="bg-teal-soft text-xs uppercase tracking-wide text-teal-deep">
                    <tr>
                        <th class="px-5 py-3 font-bold">Local</th>
                        <th class="px-5 py-3 font-bold">Entra con</th>
                        <th class="px-5 py-3 font-bold">En la app</th>
                        <th class="px-5 py-3 font-bold">Ahora</th>
                        <th class="px-5 py-3 font-bold">Tarifa</th>
                        <th class="px-5 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($restaurants as $restaurant)
                        <tr class="border-t border-navy/5">

                            <td class="px-5 py-4">
                                <div class="font-bold text-navy">{{ $restaurant->name }}</div>
                                <div class="text-xs text-navy/50">{{ $restaurant->address }}</div>
                            </td>

                            <td class="px-5 py-4 text-navy/70">
                                {{ $restaurant->user?->email ?? '— sin cuenta —' }}
                            </td>

                            {{-- "En la app" = activo. Es lo que decide el panel. --}}
                            <td class="px-5 py-4">
                                @if ($restaurant->is_active)
                                    <span class="rounded-full bg-mint/20 px-3 py-1 text-xs font-bold text-teal-deep">
                                        Activo
                                    </span>
                                @else
                                    <span class="rounded-full bg-coral/15 px-3 py-1 text-xs font-bold text-coral">
                                        Desactivado
                                    </span>
                                @endif
                            </td>

                            {{-- "Ahora" = abierto/cerrado. Eso lo maneja el propio
                                 restaurante desde su app, no el panel. --}}
                            <td class="px-5 py-4">
                                @if (! $restaurant->is_active)
                                    <span class="text-xs text-navy/40">—</span>
                                @elseif ($restaurant->is_open)
                                    <span class="text-xs font-semibold text-teal-deep">
                                        Abierto{{ $restaurant->is_busy ? ' (muy ocupado)' : '' }}
                                    </span>
                                @else
                                    <span class="text-xs font-semibold text-coral">Cerrado</span>
                                @endif
                            </td>

                            <td class="px-5 py-4 text-navy/70">
                                @if ($restaurant->delivery_fee === null)
                                    <span class="text-xs text-navy/50">De la zona</span>
                                @else
                                    ${{ $restaurant->delivery_fee }}
                                @endif
                            </td>

                            <td class="px-5 py-4">
                                <div class="flex items-center justify-end gap-2">
                                    <a href="{{ route('admin.restaurants.edit', $restaurant) }}"
                                       class="rounded-full bg-teal-soft px-4 py-2 text-xs font-bold text-teal-deep transition hover:bg-teal hover:text-white">
                                        Editar
                                    </a>

                                    <form method="POST" action="{{ route('admin.restaurants.toggle', $restaurant) }}">
                                        @csrf
                                        <button type="submit"
                                                class="{{ $restaurant->is_active
                                                    ? 'bg-coral/10 text-coral hover:bg-coral hover:text-white'
                                                    : 'bg-mint/20 text-teal-deep hover:bg-mint hover:text-white' }} rounded-full px-4 py-2 text-xs font-bold transition">
                                            {{ $restaurant->is_active ? 'Desactivar' : 'Activar' }}
                                        </button>
                                    </form>
                                </div>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>

        <p class="mt-3 text-xs text-navy/50">
            No hay botón de borrar a propósito: un local tiene pedidos e historial, y borrarlo
            dejaría esos pedidos apuntando a algo que no existe. Para sacarlo de circulación, se
            desactiva.
        </p>
    @endif

@endsection
