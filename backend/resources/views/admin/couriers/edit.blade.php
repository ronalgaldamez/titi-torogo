@extends('layouts.panel')

@section('title', 'Editar motorizado')

@section('content')

    <div class="flex items-center justify-between">
        <div>
            <h1 class="text-2xl font-extrabold">{{ $courier->name }}</h1>
            <p class="mt-1 text-sm text-navy/60">
                Motorizado #{{ $courier->id }} ·
                {{ $courier->is_active ? 'Activo' : 'Desactivado' }} ·
                {{ $courier->is_available ? 'disponible ahora' : 'no disponible' }}
            </p>
        </div>

        <a href="{{ route('admin.couriers.index') }}"
           class="rounded-full bg-white px-4 py-2 text-sm font-semibold text-navy shadow-sm transition hover:bg-teal-soft">
            Volver
        </a>
    </div>

    <form method="POST" action="{{ route('admin.couriers.update', $courier) }}"
          class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        @csrf
        @method('PUT')

        @include('admin.couriers._form', ['courier' => $courier])

        <div class="mt-6 flex items-center gap-3 border-t border-navy/10 pt-5">
            <button type="submit"
                    class="rounded-xl bg-teal px-6 py-3 font-bold text-white transition hover:bg-teal-deep">
                Guardar cambios
            </button>
            <a href="{{ route('admin.couriers.index') }}"
               class="text-sm font-medium text-navy/60 hover:text-navy">
                Cancelar
            </a>
        </div>
    </form>

    <div class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        <h2 class="text-sm font-bold">Estado en la app</h2>
        <p class="mt-1 text-sm text-navy/60">
            @if ($courier->is_active)
                Puede entrar a la app y recibir pedidos.
                Si lo desactivás, se le corta el acceso y se lo saca de disponible.
            @else
                <strong>No puede entrar</strong> a la app ni recibir pedidos. Al activarlo
                vuelve a poder entrar; la disponibilidad la prende él.
            @endif
        </p>

        <form method="POST" action="{{ route('admin.couriers.toggle', $courier) }}" class="mt-4">
            @csrf
            <button type="submit"
                    class="{{ $courier->is_active
                        ? 'bg-coral hover:opacity-90'
                        : 'bg-mint hover:opacity-90' }} rounded-xl px-6 py-3 font-bold text-white transition">
                {{ $courier->is_active ? 'Desactivar' : 'Activar' }}
            </button>
        </form>
    </div>

@endsection
