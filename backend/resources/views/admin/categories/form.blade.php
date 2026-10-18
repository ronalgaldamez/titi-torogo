@extends('layouts.panel')
@section('title', $category->exists ? 'Editar categoría' : 'Nueva categoría')
@section('content')
<h1 class="text-2xl font-extrabold">{{ $category->exists ? 'Editar categoría' : 'Nueva categoría' }}</h1>
<form method="POST" enctype="multipart/form-data" action="{{ $category->exists ? route('admin.categories.update', $category) : route('admin.categories.store') }}" class="mt-6 max-w-xl space-y-5 rounded-2xl bg-white p-6">
    @csrf
    @if ($category->exists) @method('PUT') @endif
    @if ($errors->any())
        <ul class="text-sm text-coral" role="alert">@foreach ($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul>
    @endif
    <div>
        <label for="name" class="mb-2 block font-semibold">Nombre</label>
        <input id="name" name="name" value="{{ old('name', $category->name) }}" required maxlength="80" class="w-full rounded-xl border border-navy/15 p-3">
    </div>
    <div>
        <label for="sort_order" class="mb-2 block font-semibold">Orden (los menores aparecen primero)</label>
        <input id="sort_order" type="number" name="sort_order" min="0" max="9999" required value="{{ old('sort_order', $category->sort_order) }}" class="w-full rounded-xl border border-navy/15 p-3">
    </div>
    <input type="hidden" name="is_active" value="0">
    <div>
        <label for="icon" class="mb-2 block font-semibold">Icono personalizado (opcional)</label>
        @if ($category->icon_path)
            <img src="{{ route('api.category.icon', $category) }}?v={{ sha1($category->icon_path) }}" alt="Icono actual de {{ $category->name }}" class="mb-3 h-16 w-16 object-contain">
            <label class="mb-3 flex items-center gap-3"><input type="checkbox" name="remove_icon" value="1"> Quitar imagen y usar el icono predeterminado</label>
        @endif
        <input id="icon" type="file" name="icon" accept="image/png,image/jpeg,image/webp" class="block w-full">
        <p class="mt-2 text-sm">PNG, JPG o WebP. Máximo 2 MB y 1024 × 1024 píxeles. Si no elegís imagen, se usa el icono predeterminado. Al editar, dejar este campo vacío conserva la imagen actual.</p>
    </div>
    <label class="flex items-center gap-3"><input type="checkbox" name="is_active" value="1" @checked(old('is_active', $category->is_active))> Categoría activa</label>
    <p class="text-sm">Al desactivarla se oculta al cliente y deja de estar disponible para seleccionar. Los menús no cambian.</p>
    <div class="flex flex-wrap gap-4">
        <button class="rounded-xl bg-teal px-6 py-3 font-bold text-white" type="submit">Guardar categoría</button>
        <a class="px-4 py-3" href="{{ route('admin.categories.index') }}">Cancelar</a>
    </div>
</form>
@endsection
