@extends('layouts.panel')

@section('title', 'Nuevo motorizado')

@section('content')

    <div class="flex items-center justify-between">
        <div>
            <h1 class="text-2xl font-extrabold">Nuevo motorizado</h1>
            <p class="mt-1 text-sm text-navy/60">
                Se crea su cuenta. La disponibilidad la prende él desde su app.
            </p>
        </div>

        <a href="{{ route('admin.couriers.index') }}"
           class="rounded-full bg-white px-4 py-2 text-sm font-semibold text-navy shadow-sm transition hover:bg-teal-soft">
            Volver
        </a>
    </div>

    <form method="POST" action="{{ route('admin.couriers.store') }}"
          class="mt-6 rounded-2xl bg-white p-6 shadow-sm">
        @csrf

        @include('admin.couriers._form', ['courier' => null])

        <div class="mt-6 flex items-center gap-3 border-t border-navy/10 pt-5">
            <button type="submit"
                    class="rounded-xl bg-teal px-6 py-3 font-bold text-white transition hover:bg-teal-deep">
                Crear motorizado
            </button>
            <a href="{{ route('admin.couriers.index') }}"
               class="text-sm font-medium text-navy/60 hover:text-navy">
                Cancelar
            </a>
        </div>
    </form>

@endsection
