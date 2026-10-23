@extends('layouts.panel')
@section('title', 'Página web')
@section('content')
<div class="flex flex-wrap items-center justify-between gap-4">
    <div><h1 class="text-2xl font-extrabold">Página web de ToroGo</h1><p class="mt-2 text-sm text-navy/70">Editá los textos y las imágenes de la landing. Guardar publica los cambios inmediatamente.</p></div>
    <a href="{{ route('landing') }}" target="_blank" rel="noopener" class="rounded-xl bg-teal px-5 py-3 font-bold text-white">Ver página web</a>
</div>
@if ($errors->any())
    <div role="alert" class="mt-6 rounded-xl bg-coral/10 p-5 text-coral"><strong>No se guardaron los cambios.</strong><ul class="mt-2 list-disc pl-5">@foreach ($errors->all() as $error)<li>{{ $error }}</li>@endforeach</ul></div>
@endif
<form method="POST" action="{{ route('admin.landing.update') }}" enctype="multipart/form-data" class="mt-6 space-y-5">
    @csrf @method('PUT')
    <section class="rounded-2xl bg-white p-6 shadow-sm">
        <h2 class="text-lg font-bold">Imágenes</h2><p class="mt-1 text-sm text-navy/60">JPG, PNG o WebP. Máximo 3 MB y 3000 × 3000 píxeles. Formato horizontal recomendado.</p>
        <div class="mt-5 grid gap-6 md:grid-cols-2">
        @foreach (config('landing.images') as $slot => $image)
            <div><label class="block text-sm font-bold" for="image-{{ $slot }}">{{ $image['label'] }}</label><img src="{{ $images[$slot] }}" alt="{{ $image['label'] }} actual" class="my-3 h-40 w-full rounded-xl object-cover"><input id="image-{{ $slot }}" name="images[{{ $slot }}]" type="file" accept="image/jpeg,image/png,image/webp" class="block w-full rounded-xl border border-navy/20 p-3 text-sm"><label class="mt-3 flex items-center gap-2 text-sm"><input type="checkbox" name="remove_images[{{ $slot }}]" value="1" @checked(old('remove_images.'.$slot))> Volver a la imagen predeterminada</label>@error('images.'.$slot)<p class="mt-2 text-sm text-coral">{{ $message }}</p>@enderror</div>
        @endforeach
        </div>
    </section>
    @foreach (config('landing.sections') as $group => $fields)
    <details class="rounded-2xl bg-white p-6 shadow-sm" @if ($loop->first) open @endif>
        <summary class="cursor-pointer font-bold">{{ $group }}</summary>
        <div class="mt-5 grid gap-5 md:grid-cols-2">
        @foreach ($fields as $key => $field)
            <div><label for="text-{{ $key }}" class="mb-2 block text-sm font-semibold">{{ $field[0] }}</label>
            @if ($key === 'contact_email')
                <input id="text-{{ $key }}" type="email" name="content[{{ $key }}]" maxlength="255" value="{{ old('content.'.$key, $content[$key]) }}" class="w-full rounded-xl border border-navy/20 px-4 py-3">
            @else
                <textarea id="text-{{ $key }}" name="content[{{ $key }}]" rows="3" maxlength="1200" required class="w-full rounded-xl border border-navy/20 px-4 py-3">{{ old('content.'.$key, $content[$key]) }}</textarea>
            @endif
            @error('content.'.$key)<p class="mt-2 text-sm text-coral">{{ $message }}</p>@enderror</div>
        @endforeach
        </div>
    </details>
    @endforeach
    <div class="flex flex-wrap items-center gap-4"><button class="rounded-xl bg-teal px-6 py-3 font-bold text-white">Guardar y publicar</button><span class="text-sm text-navy/60">Solo cambia la página web; el contenido de la app no se modifica.</span></div>
</form>
@endsection
