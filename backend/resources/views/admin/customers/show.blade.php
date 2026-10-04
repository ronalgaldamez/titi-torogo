@extends('layouts.panel')

@section('title', 'Cliente')

@section('content')

    <div class="flex flex-wrap items-center justify-between gap-4">
        <div>
            <h1 class="text-2xl font-extrabold">{{ $customer->name }}</h1>
            <p class="mt-1 text-sm text-navy/60">
                {{ $customer->email }} · cliente desde {{ $customer->created_at->format('d/m/Y') }} ·
                <span class="font-semibold">${{ $spent }}</span> gastado
            </p>
        </div>

        <a href="{{ route('admin.customers.index') }}"
           class="rounded-full bg-white px-4 py-2 text-sm font-semibold text-navy shadow-sm transition hover:bg-teal-soft">
            Volver
        </a>
    </div>

    <div class="mt-6 grid gap-6 lg:grid-cols-3">

        {{-- --------------------------- Sus pedidos --------------------------- --}}
        <div class="lg:col-span-2">
            <div class="rounded-2xl bg-white p-6 shadow-sm">
                <h2 class="text-sm font-bold">Sus pedidos</h2>

                @if ($orders->isEmpty())
                    <p class="mt-3 text-sm text-navy/60">Todavía no pidió nada.</p>
                @else
                    <table class="mt-4 w-full text-left text-sm">
                        <thead class="text-xs uppercase tracking-wide text-navy/50">
                            <tr>
                                <th class="pb-2 font-bold">#</th>
                                <th class="pb-2 font-bold">Cuándo</th>
                                <th class="pb-2 font-bold">Restaurante</th>
                                <th class="pb-2 font-bold">Estado</th>
                                <th class="pb-2 font-bold text-right">Total</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach ($orders as $order)
                                <tr class="border-t border-navy/5">
                                    <td class="py-2">
                                        <a href="{{ route('admin.orders.show', $order) }}"
                                           class="font-bold text-teal-deep underline">
                                            {{ $order->id }}
                                        </a>
                                    </td>
                                    <td class="py-2 text-xs text-navy/70">{{ $order->created_at->format('d/m H:i') }}</td>
                                    <td class="py-2 text-navy/80">{{ $order->restaurant?->name ?? '—' }}</td>
                                    <td class="py-2 text-navy/70">{{ $order->status->label() }}</td>
                                    <td class="py-2 text-right font-semibold text-navy">${{ $order->total }}</td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>

                    <div class="mt-4">
                        {{ $orders->links() }}
                    </div>
                @endif
            </div>
        </div>

        {{-- ------------------------- Donde vive ------------------------- --}}
        <div>
            <div class="rounded-2xl bg-white p-6 shadow-sm">
                <h2 class="text-sm font-bold">Sus direcciones</h2>

                @if ($customer->addresses->isEmpty())
                    <p class="mt-3 text-sm text-navy/60">No tiene direcciones guardadas.</p>
                @else
                    <div class="mt-3 space-y-3">
                        @foreach ($customer->addresses as $address)
                            <div class="rounded-xl bg-background p-4">
                                <div class="text-sm font-bold text-navy">
                                    {{ $address->label }}
                                    @if ($address->is_default)
                                        <span class="ml-1 rounded-full bg-teal-soft px-2 py-0.5 text-xs font-bold text-teal-deep">
                                            principal
                                        </span>
                                    @endif
                                </div>
                                <div class="mt-1 text-xs text-navy/70">{{ $address->address }}</div>
                                @if ($address->reference)
                                    <div class="mt-1 text-xs text-navy/50">{{ $address->reference }}</div>
                                @endif
                            </div>
                        @endforeach
                    </div>
                @endif
            </div>
        </div>
    </div>

@endsection
