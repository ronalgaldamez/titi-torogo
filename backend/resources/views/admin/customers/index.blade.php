@extends('layouts.panel')

@section('title', 'Clientes')

@section('content')

    <div>
        <h1 class="text-2xl font-extrabold">Clientes</h1>
        <p class="mt-1 text-sm text-navy/60">
            {{ $customers->total() }} {{ $customers->total() === 1 ? 'cuenta' : 'cuentas' }} de cliente.
            Lo gastado cuenta solo los pedidos <strong>entregados</strong>.
        </p>
    </div>

    @if ($customers->isEmpty())
        <div class="mt-6 rounded-2xl bg-white p-8 text-center shadow-sm">
            <p class="text-sm text-navy/60">Todavía no hay clientes registrados.</p>
        </div>
    @else
        <div class="mt-6 overflow-hidden rounded-2xl bg-white shadow-sm">
            <table class="w-full text-left text-sm">
                <thead class="bg-teal-soft text-xs uppercase tracking-wide text-teal-deep">
                    <tr>
                        <th class="px-5 py-3 font-bold">Cliente</th>
                        <th class="px-5 py-3 font-bold">Desde</th>
                        <th class="px-5 py-3 font-bold text-center">Pedidos</th>
                        <th class="px-5 py-3 font-bold text-right">Gastado</th>
                        <th class="px-5 py-3"></th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($customers as $customer)
                        <tr class="border-t border-navy/5">
                            <td class="px-5 py-4">
                                <div class="font-bold text-navy">{{ $customer->name }}</div>
                                <div class="text-xs text-navy/50">{{ $customer->email }}</div>
                            </td>

                            <td class="px-5 py-4 text-xs text-navy/70">
                                {{ $customer->created_at->format('d/m/Y') }}
                            </td>

                            <td class="px-5 py-4 text-center text-navy/80">
                                {{ $customer->orders_count }}
                            </td>

                            <td class="px-5 py-4 text-right font-semibold text-navy">
                                ${{ $spent->get($customer->id, '0.00') }}
                            </td>

                            <td class="px-5 py-4 text-right">
                                <a href="{{ route('admin.customers.show', $customer) }}"
                                   class="rounded-full bg-teal-soft px-4 py-2 text-xs font-bold text-teal-deep transition hover:bg-teal hover:text-white">
                                    Ver
                                </a>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>

        <div class="mt-4">
            {{ $customers->links() }}
        </div>
    @endif

@endsection
