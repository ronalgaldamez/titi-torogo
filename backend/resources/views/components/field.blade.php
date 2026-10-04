{{--
    Un campo de formulario, con su etiqueta, su ayuda y su error.

    Es un componente porque los formularios del panel piden los mismos diez
    campos dos veces (crear y editar): escrito una vez, los dos quedan iguales
    y no hay forma de que uno muestre los errores y el otro no.

    Uso:
      <x-field name="name" label="Nombre del local" :value="$restaurant->name" required />
      <x-field name="delivery_fee" label="Tarifa de envío" type="number" step="0.01" hint="..." />
--}}
@props([
    'name',
    'label',
    'value' => null,
    'type' => 'text',
    'required' => false,
    'step' => null,
    'hint' => null,
])

<div>
    <label for="{{ $name }}" class="mb-1 block text-sm font-semibold">
        {{ $label }}@if ($required)<span class="text-coral"> *</span>@endif
    </label>

    <input
        id="{{ $name }}"
        name="{{ $name }}"
        type="{{ $type }}"
        value="{{ old($name, $value) }}"
        @if ($step) step="{{ $step }}" @endif
        @if ($required) required @endif
        {{ $attributes->merge(['class' => 'w-full rounded-xl border border-navy/15 px-4 py-2.5 outline-none transition focus:border-teal focus:ring-2 focus:ring-teal/20']) }}
    >

    @if ($hint)
        <p class="mt-1 text-xs text-navy/50">{{ $hint }}</p>
    @endif

    @error($name)
        <p class="mt-1 text-xs font-medium text-coral">{{ $message }}</p>
    @enderror
</div>
