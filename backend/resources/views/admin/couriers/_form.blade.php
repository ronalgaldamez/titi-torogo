{{--
    Los campos de un motorizado, compartidos entre crear y editar.

    Ojo con lo que NO esta: la disponibilidad ("hoy salgo a repartir") no se
    edita desde el panel. Es del motorizado, no del administrador.

    Espera: $courier (puede ser null al crear).
--}}
@php
    $c = $courier ?? null;
@endphp

<div class="grid gap-5 sm:grid-cols-2">

    <div class="sm:col-span-2">
        <h3 class="text-xs font-bold uppercase tracking-wide text-navy/50">La cuenta</h3>
        <p class="mt-1 text-xs text-navy/50">Con esto entra el motorizado a su app.</p>
    </div>

    <x-field name="name" label="Nombre" :value="$c?->name" required />

    <x-field name="phone" label="Teléfono" :value="$c?->phone" required
             hint="El dato con el que se lo ubica cuando un pedido se traba." />

    <x-field name="email" label="Correo" type="email" :value="$c?->email" required />

    <div>
        <label for="vehicle" class="mb-1 block text-sm font-semibold">
            Vehículo<span class="text-coral"> *</span>
        </label>
        <select id="vehicle" name="vehicle" required
                class="w-full rounded-xl border border-navy/15 bg-white px-4 py-2.5 outline-none transition focus:border-teal focus:ring-2 focus:ring-teal/20">
            <option value="">Elegí…</option>
            @foreach (\App\Enums\Vehicle::cases() as $vehicle)
                <option value="{{ $vehicle->value }}"
                    @selected(old('vehicle', $c?->vehicle) === $vehicle->value)>
                    {{ $vehicle->label() }}
                </option>
            @endforeach
        </select>
        @error('vehicle')
            <p class="mt-1 text-xs font-medium text-coral">{{ $message }}</p>
        @enderror
    </div>

    <x-field name="password" label="Contraseña" type="password"
             :required="$c === null"
             :hint="$c === null
                 ? 'Mínimo 8 caracteres.'
                 : 'Dejala vacía para conservar la que ya tiene.'" />

</div>
