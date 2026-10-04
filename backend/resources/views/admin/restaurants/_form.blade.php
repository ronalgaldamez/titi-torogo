{{--
    Los campos de un restaurante, compartidos entre crear y editar.

    Se separo en un archivo porque son los MISMOS diez campos: si estuvieran
    escritos dos veces, tarde o temprano uno tendria un campo que el otro no.

    Espera: $restaurant (puede ser null al crear).
--}}
@php
    $r = $restaurant ?? null;
@endphp

<div class="grid gap-5 sm:grid-cols-2">

    {{-- ------------------------- La cuenta ------------------------- --}}

    <div class="sm:col-span-2">
        <h3 class="text-xs font-bold uppercase tracking-wide text-navy/50">La cuenta</h3>
        <p class="mt-1 text-xs text-navy/50">
            Con esto entra el local a su app. Es la misma cuenta para el teléfono.
        </p>
    </div>

    <x-field name="name" label="Nombre del local" :value="$r?->name" required
             hint="Es el nombre que ve el cliente, y también el de la cuenta." />

    <x-field name="email" label="Correo" type="email" :value="$r?->user?->email" required
             hint="Con este correo entra el restaurante a la app." />

    <x-field name="password" label="Contraseña" type="password"
             :required="$r === null"
             :hint="$r === null
                 ? 'Mínimo 8 caracteres.'
                 : 'Dejala vacía para conservar la que ya tiene.'" />

    <div></div>

    {{-- -------------------------- El local -------------------------- --}}

    <div class="sm:col-span-2 mt-2">
        <h3 class="text-xs font-bold uppercase tracking-wide text-navy/50">El local</h3>
    </div>

    <x-field name="address" label="Dirección" :value="$r?->address" required />
    <x-field name="phone" label="Teléfono" :value="$r?->phone" required />

    <x-field name="latitude" label="Latitud" type="number" step="0.0000001"
             :value="$r?->latitude" required
             hint="Ejemplo: 14.1012037 (así se ve en el mapa)." />

    <x-field name="longitude" label="Longitud" type="number" step="0.0000001"
             :value="$r?->longitude" required
             hint="Ejemplo: -89.1506165. El signo menos importa." />

    <x-field name="prep_time_minutes" label="Tiempo de preparación (minutos)"
             type="number" :value="$r?->prep_time_minutes ?? 15" required
             hint="Lo que tarda la cocina. El cliente lo suma al envío." />

    <x-field name="delivery_fee" label="Tarifa de envío propia (opcional)"
             type="number" step="0.01" :value="$r?->delivery_fee"
             hint="Vacío = usa la tarifa de la zona. Poné 0 para envío gratis." />

    <div class="sm:col-span-2">
        <x-field name="description" label="Descripción (opcional)" :value="$r?->description"
                 hint="Una línea corta: qué se come ahí. Se ve en el Home del cliente." />
    </div>
</div>
