@extends('layouts.panel')

@section('title', 'Editar restaurante')

@section('content')

    <div class="flex items-center justify-between">
        <div>
            <h1 class="text-2xl font-extrabold">{{ $restaurant->name }}</h1>
            <p class="mt-1 text-sm text-navy/60">
                Local #{{ $restaurant->id }} ·
                {{ $restaurant->is_active ? 'Activo' : 'Desactivado' }} ·
                {{ $restaurant->is_open ? 'abierto ahora' : 'cerrado ahora' }}
            </p>
        </div>

        <a href="{{ route('admin.restaurants.index') }}"
           class="rounded-full bg-white px-4 py-2 text-sm font-semibold text-navy shadow-sm transition hover:bg-teal-soft">
            Volver
        </a>
    </div>

    <form method="POST" action="{{ route('admin.restaurants.update', $restaurant) }}"
          class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        @csrf
        @method('PUT')

        @include('admin.restaurants._form', ['restaurant' => $restaurant])

        <div class="mt-6 flex items-center gap-3 border-t border-navy/10 pt-5">
            <button type="submit"
                    class="rounded-xl bg-teal px-6 py-3 font-bold text-white transition hover:bg-teal-deep">
                Guardar cambios
            </button>
            <a href="{{ route('admin.restaurants.index') }}"
               class="text-sm font-medium text-navy/60 hover:text-navy">
                Cancelar
            </a>
        </div>
    </form>

    {{--
        Activar/desactivar va APARTE del formulario de datos, en su propio
        form: si estuviera adentro, guardar un telefono tambien mandaria el
        estado, y un descuido podria reactivar un local que se dio de baja por
        un motivo.
    --}}
    <div class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        <h2 class="text-sm font-bold">Estado en la app</h2>
        <p class="mt-1 text-sm text-navy/60">
            @if ($restaurant->is_active)
                Ahora <strong>aparece</strong> en el catálogo del cliente.
                Si lo desactivás, deja de aparecer y su cuenta tampoco puede entrar a la app.
            @else
                Ahora <strong>no aparece</strong> en el catálogo, y su cuenta no puede entrar a la app.
                Al activarlo vuelve a estar disponible.
            @endif
        </p>

        <form method="POST" action="{{ route('admin.restaurants.toggle', $restaurant) }}" class="mt-4">
            @csrf
            <button type="submit"
                    class="{{ $restaurant->is_active
                        ? 'bg-coral hover:opacity-90'
                        : 'bg-mint hover:opacity-90' }} rounded-xl px-6 py-3 font-bold text-white transition">
                {{ $restaurant->is_active ? 'Desactivar' : 'Activar' }}
            </button>
        </form>
    </div>

@endsection
