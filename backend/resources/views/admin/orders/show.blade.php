@extends('layouts.panel')

@section('title', 'Pedido #' . $order->id)

@section('content')

    @php
        $activo = $order->status->isActive();
        // El recorrido, para pintar la linea de tiempo. Los finales por el
        // costado (rechazado, cancelado) no son etapas: se muestran aparte.
        $etapas = [
            ['status' => \App\Enums\OrderStatus::Pending, 'at' => $order->created_at, 'label' => 'Pedido hecho'],
            ['status' => \App\Enums\OrderStatus::Accepted, 'at' => $order->accepted_at, 'label' => 'El restaurante aceptó'],
            ['status' => \App\Enums\OrderStatus::Ready, 'at' => $order->ready_at, 'label' => 'Listo para recoger'],
            ['status' => \App\Enums\OrderStatus::PickedUp, 'at' => $order->picked_up_at, 'label' => 'El motorizado lo recogió'],
            ['status' => \App\Enums\OrderStatus::Delivered, 'at' => $order->delivered_at, 'label' => 'Entregado'],
        ];
    @endphp

    <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
            <h1 class="text-2xl font-extrabold">Pedido #{{ $order->id }}</h1>
            <p class="mt-1 text-sm text-navy/60">
                {{ $order->created_at->format('d/m/Y H:i') }} ·
                {{ $order->restaurant?->name ?? 'restaurante borrado' }} ·
                <span class="font-semibold">{{ $order->status->label() }}</span>
            </p>
        </div>

        <a href="{{ route('admin.orders.index') }}"
           class="rounded-full bg-white px-4 py-2 text-sm font-semibold text-navy shadow-sm transition hover:bg-teal-soft">
            Volver
        </a>
    </div>

    <div class="mt-6 grid gap-6 lg:grid-cols-3">

        {{-- ------------------------- Lo que se pidio ------------------------- --}}
        <div class="lg:col-span-2 space-y-6">

            <div class="rounded-2xl bg-white p-6 shadow-sm">
                <h2 class="text-sm font-bold">Lo que se pidió</h2>

                <table class="mt-4 w-full text-left text-sm">
                    <thead class="text-xs uppercase tracking-wide text-navy/50">
                        <tr>
                            <th class="pb-2 font-bold">Plato</th>
                            <th class="pb-2 font-bold text-center">Cantidad</th>
                            <th class="pb-2 font-bold text-right">Precio</th>
                            <th class="pb-2 font-bold text-right">Subtotal</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach ($order->items as $item)
                            <tr class="border-t border-navy/5">
                                <td class="py-2 text-navy">{{ $item->name }}</td>
                                <td class="py-2 text-center text-navy/70">{{ $item->quantity }}</td>
                                <td class="py-2 text-right text-navy/70">${{ $item->unit_price }}</td>
                                <td class="py-2 text-right font-semibold text-navy">${{ $item->subtotal }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>

                <div class="mt-4 space-y-1 border-t border-navy/10 pt-4 text-sm">
                    <div class="flex justify-between text-navy/70">
                        <span>Platos</span><span>${{ $order->subtotal }}</span>
                    </div>
                    <div class="flex justify-between text-navy/70">
                        <span>Envío (al cliente)</span><span>${{ $order->delivery_fee }}</span>
                    </div>
                    <div class="flex justify-between text-navy/50 text-xs">
                        <span>De eso, al motorizado</span><span>${{ $order->courier_fee }}</span>
                    </div>
                    <div class="flex justify-between text-navy/50 text-xs">
                        <span>De eso, para ToroGo</span><span>${{ $order->platform_fee }}</span>
                    </div>
                    <div class="flex justify-between border-t border-navy/10 pt-2 text-base font-extrabold text-navy">
                        <span>Total (en efectivo)</span><span>${{ $order->total }}</span>
                    </div>
                </div>

                @if ($order->notes)
                    <div class="mt-4 rounded-xl bg-teal-soft px-4 py-3 text-sm text-teal-deep">
                        <span class="font-bold">Nota del cliente:</span> {{ $order->notes }}
                    </div>
                @endif
            </div>

            {{-- --------------------------- El recorrido --------------------------- --}}
            <div class="rounded-2xl bg-white p-6 shadow-sm">
                <h2 class="text-sm font-bold">Qué pasó con este pedido</h2>

                <ol class="mt-4 space-y-3">
                    @foreach ($etapas as $etapa)
                        @php $hecho = $etapa['at'] !== null; @endphp
                        <li class="flex items-start gap-3">
                            <span class="mt-1 h-3 w-3 shrink-0 rounded-full {{ $hecho ? 'bg-teal' : 'bg-navy/15' }}"></span>
                            <div>
                                <div class="text-sm {{ $hecho ? 'font-semibold text-navy' : 'text-navy/40' }}">
                                    {{ $etapa['label'] }}
                                </div>
                                <div class="text-xs text-navy/50">
                                    {{ $hecho ? $etapa['at']->format('d/m/Y H:i') : 'todavía no' }}
                                </div>
                            </div>
                        </li>
                    @endforeach

                    @if ($order->status === \App\Enums\OrderStatus::Cancelled || $order->status === \App\Enums\OrderStatus::Rejected)
                        <li class="flex items-start gap-3">
                            <span class="mt-1 h-3 w-3 shrink-0 rounded-full bg-coral"></span>
                            <div>
                                <div class="text-sm font-semibold text-coral">{{ $order->status->label() }}</div>
                                <div class="text-xs text-navy/50">
                                    {{ $order->cancelled_at?->format('d/m/Y H:i') ?? 'sin hora' }}
                                </div>
                            </div>
                        </li>
                    @endif
                </ol>
            </div>
        </div>

        {{-- ------------------------- A quien y donde ------------------------- --}}
        <div class="space-y-6">

            <div class="rounded-2xl bg-white p-6 shadow-sm">
                <h2 class="text-sm font-bold">La entrega</h2>
                <div class="mt-3 space-y-2 text-sm">
                    <div>
                        <div class="text-xs font-semibold text-navy/50">Cliente</div>
                        <div class="text-navy">{{ $order->user?->name ?? '—' }}</div>
                    </div>
                    <div>
                        <div class="text-xs font-semibold text-navy/50">Dirección</div>
                        <div class="text-navy">{{ $order->delivery_address }}</div>
                    </div>
                    @if ($order->delivery_reference)
                        <div>
                            <div class="text-xs font-semibold text-navy/50">Referencia</div>
                            <div class="text-navy/80">{{ $order->delivery_reference }}</div>
                        </div>
                    @endif
                    <div>
                        <div class="text-xs font-semibold text-navy/50">Motorizado</div>
                        <div class="text-navy">
                            {{ $order->courier?->name ?? 'sin asignar' }}
                            @if ($order->courier?->phone)
                                <span class="text-navy/50">· {{ $order->courier->phone }}</span>
                            @endif
                        </div>
                    </div>
                </div>
            </div>

            {{-- --------------------- Las intervenciones --------------------- --}}
            <div class="rounded-2xl bg-yellow/20 p-6">
                <h2 class="text-sm font-bold">Intervenir</h2>

                @if (! $activo)
                    <p class="mt-2 text-sm text-navy/70">
                        Este pedido ya está cerrado ({{ $order->status->label() }}). No hay nada que hacer.
                    </p>
                @else
                    {{-- Reasignar motorizado --}}
                    <form method="POST" action="{{ route('admin.orders.assign', $order) }}" class="mt-3">
                        @csrf
                        <label for="courier_id" class="mb-1 block text-xs font-semibold text-navy/70">
                            Asignarle un motorizado
                        </label>
                        <select id="courier_id" name="courier_id"
                                class="w-full rounded-xl border border-navy/15 bg-white px-4 py-2.5 outline-none focus:border-teal">
                            <option value="">Elegí…</option>
                            @foreach ($couriers as $courier)
                                <option value="{{ $courier->id }}" @selected($order->courier_id === $courier->id)>
                                    {{ $courier->name }}
                                    @if ($courier->is_available) (disponible) @endif
                                </option>
                            @endforeach
                        </select>
                        <button type="submit"
                                class="mt-2 w-full rounded-xl bg-teal px-4 py-2.5 font-bold text-white transition hover:bg-teal-deep">
                            Asignar
                        </button>
                        @if (! in_array($order->status, [\App\Enums\OrderStatus::Ready, \App\Enums\OrderStatus::PickedUp], true))
                            <p class="mt-2 text-xs text-navy/60">
                                Solo se puede asignar cuando el pedido está listo para recoger o en camino.
                            </p>
                        @endif
                    </form>

                    @if ($order->courier_id !== null && $order->status === \App\Enums\OrderStatus::Ready)
                        <form method="POST" action="{{ route('admin.orders.release', $order) }}" class="mt-3">
                            @csrf
                            <button type="submit"
                                    class="w-full rounded-xl bg-white px-4 py-2.5 text-sm font-bold text-navy transition hover:bg-teal-soft">
                                Quitarle el motorizado y devolverlo a disponibles
                            </button>
                        </form>
                    @endif

                    {{-- Cancelar --}}
                    <form method="POST" action="{{ route('admin.orders.cancel', $order) }}" class="mt-4 border-t border-navy/10 pt-4">
                        @csrf
                        <p class="text-xs text-navy/60">
                            Cancelar es definitivo: el pedido no se puede reabrir. El cliente lo ve al instante
                            en su app.
                        </p>
                        <button type="submit"
                                class="mt-2 w-full rounded-xl bg-coral px-4 py-3 font-bold text-white transition hover:opacity-90">
                            Cancelar el pedido #{{ $order->id }}
                        </button>
                    </form>
                @endif
            </div>
        </div>
    </div>

@endsection
