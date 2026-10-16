@extends('layouts.panel')
@section('title', 'Categorías')
@section('content')
<div class="flex flex-wrap items-center justify-between gap-4">
    <div>
        <h1 class="text-2xl font-extrabold">Categorías de restaurantes</h1>
        <p class="mt-2 text-sm">Se muestran en el inicio del cliente. Cada negocio elige las que ofrece desde Mi local.</p>
    </div>
    <a href="{{ route('admin.categories.create') }}" class="rounded-xl bg-teal px-5 py-3 font-bold text-white">Nueva categoría</a>
</div>
<div class="mt-6 overflow-x-auto rounded-2xl bg-white p-5">
    <table class="w-full text-left text-sm">
        <thead><tr class="border-b border-navy/10"><th class="p-3">Nombre</th><th class="p-3">Orden</th><th class="p-3">Estado</th><th class="p-3">Acción</th></tr></thead>
        <tbody>
        @forelse ($categories as $category)
            <tr class="border-b border-navy/10">
                <td class="p-3 font-bold">{{ $category->name }}</td>
                <td class="p-3">{{ $category->sort_order }}</td>
                <td class="p-3">{{ $category->is_active ? 'Activa' : 'Inactiva' }}</td>
                <td class="p-3"><a class="font-bold text-teal-deep" href="{{ route('admin.categories.edit', $category) }}">Editar {{ $category->name }}</a></td>
            </tr>
        @empty
            <tr><td colspan="4" class="p-5">Todavía no hay categorías.</td></tr>
        @endforelse
        </tbody>
    </table>
</div>
<div class="mt-4">{{ $categories->links() }}</div>
@endsection
