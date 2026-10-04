@extends('layouts.panel')

@section('title', 'Motorizados')

@section('content')

    <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
            <h1 class="text-2xl font-extrabold">Motorizados</h1>
            <p class="mt-1 text-sm text-navy/60">
                {{ $couriers->count() }}
                {{ $couriers->count() === 1 ? 'motorizado' : 'motorizados' }}
                @if ($search !== '')
                    que coinciden con «{{ $search }}»
                @endif
            </p>
        </div>

        <a href="{{ route('admin.couriers.create') }}"
           class="rounded-xl bg-teal px-5 py-3 font-bold text-white transition hover:bg-teal-deep">
            Nuevo motorizado
        </a>
    </div>

    <form method="GET" action="{{ route('admin.couriers.index') }}" class="mt-6 flex gap-2">
        <input name="buscar" value="{{ $search }}" placeholder="Buscar por nombre o correo…"
               class="w-full max-w-sm rounded-xl border border-navy/15 bg-white px-4 py-2.5 outline-none transition focus:border-teal focus:ring-2 focus:ring-teal/20">
        <button type="submit"
                class="rounded-xl bg-white px-5 py-2.5 font-semibold text-navy shadow-sm transition hover:bg-teal-soft">
            Buscar
        </button>
        @if ($search !== '')
            <a href="{{ route('admin.couriers.index') }}"
               class="rounded-xl px-4 py-2.5 text-sm font-medium text-navy/60 hover:text-navy">
                Limpiar
            </a>
        @endif
    </form>

    @if ($couriers->isEmpty())
        <div class="mt-6 rounded-2xl bg-white p-8 text-center shadow-sm">
            <p class="text-sm text-navy/60">
                @if ($search !== '')
                    No hay ningún motorizado que coincida con esa búsqueda.
                @else
                    Todavía no hay motorizados. Empezá con «Nuevo motorizado».
                @endif
            </p>
        </div>
    @else
        <div class="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm">
            <table class="w-full text-left text-sm">
                <thead class="bg-teal-soft text-xs uppercase tracking-wide text-teal-deep">
                    <tr>
                        <th class="px-5 py-3 font-bold">Motorizado</th>
                        <th class="px-5 py-3 font-bold">Vehículo</th>
                        <th class="px-5 py-3 font-bold">En la app</th>
                        <th class="px-5 py-3 font-bold">Ahora</th>
                        <th class="px-5 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($couriers as $courier)
                        <tr class="border-t border-navy/5">

                            <td class="px-5 py-4">
                                <div class="font-bold text-navy">{{ $courier->name }}</div>
                                <div class="text-xs text-navy/50">
                                    {{ $courier->email }}
                                    @if ($courier->phone)
                                        · {{ $courier->phone }}
                                    @endif
                                </div>
                            </td>

                            <td class="px-5 py-4 text-navy/70">
                                {{ $courier->vehicle
                                    ? \App\Enums\Vehicle::tryFrom($courier->vehicle)?->label()
                                    : '—' }}
                            </td>

                            {{-- "En la app" = activo. Lo decide el panel. --}}
                            <td class="px-5 py-4">
                                @if ($courier->is_active)
                                    <span class="rounded-full bg-mint/20 px-3 py-1 text-xs font-bold text-teal-deep">
                                        Activo
                                    </span>
                                @else
                                    <span class="rounded-full bg-coral/15 px-3 py-1 text-xs font-bold text-coral">
                                        Desactivado
                                    </span>
                                @endif
                            </td>

                            {{-- "Ahora" = disponible. Eso lo maneja él desde su app,
                                 y desde el panel solo se mira. --}}
                            <td class="px-5 py-4">
                                @if (! $courier->is_active)
                                    <span class="text-xs text-navy/40">—</span>
                                @elseif ($courier->is_available)
                                    <span class="text-xs font-semibold text-teal-deep">Disponible</span>
                                @else
                                    <span class="text-xs text-navy/50">No disponible</span>
                                @endif
                            </td>

                            <td class="px-5 py-4">
                                <div class="flex items-center justify-end gap-2">
                                    <a href="{{ route('admin.couriers.edit', $courier) }}"
                                       class="rounded-full bg-teal-soft px-4 py-2 text-xs font-bold text-teal-deep transition hover:bg-teal hover:text-white">
                                        Editar
                                    </a>

                                    <form method="POST" action="{{ route('admin.couriers.toggle', $courier) }}">
                                        @csrf
                                        <button type="submit"
                                                class="{{ $courier->is_active
                                                    ? 'bg-coral/10 text-coral hover:bg-coral hover:text-white'
                                                    : 'bg-mint/20 text-teal-deep hover:bg-mint hover:text-white' }} rounded-full px-4 py-2 text-xs font-bold transition">
                                            {{ $courier->is_active ? 'Desactivar' : 'Activar' }}
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
            «En la app» y «Ahora» son dos cosas distintas: lo primero lo decidís vos desde acá,
            y lo segundo lo decide el motorizado desde su teléfono cuando sale a repartir.
        </p>
    @endif

@endsection
