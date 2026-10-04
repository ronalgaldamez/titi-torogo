{{--
    El marco del panel: la barra de arriba y el contenido.
    Todas las pantallas del panel salen de aca, asi el logo, el menu y el boton
    de salir se escriben UNA vez.
--}}
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Panel') · ToroGo</title>

    {{--
        Vite: en desarrollo el contenedor "node" sirve el CSS al instante
        (localhost:5173) y en produccion queda compilado. Por eso no hay que
        escribir Tailwind a mano en el HTML.
    --}}
    @vite(['resources/css/app.css'])
</head>
<body class="min-h-screen bg-background text-navy antialiased">

    <header class="bg-navy text-white">
        <div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">

            {{-- El mismo logotipo que la app: "Toro" en el color de marca y "Go" en blanco. --}}
            <a href="{{ route('admin.dashboard') }}" class="text-xl font-extrabold tracking-tight">
                <span class="text-mint">Toro</span><span class="text-white">Go</span>
                <span class="ml-2 text-sm font-medium text-teal-soft">Administración</span>
            </a>

            <form method="POST" action="{{ route('admin.logout') }}">
                @csrf
                <button type="submit"
                        class="rounded-full bg-white/10 px-4 py-2 text-sm font-semibold text-white transition hover:bg-white/20">
                    Cerrar sesión
                </button>
            </form>
        </div>

        {{--
            Las secciones del panel. Solo estan las que EXISTEN: un menu con
            "Pedidos" que lleva a una pagina en blanco confunde mas de lo que
            ayuda. Las que faltan se van sumando aca.
        --}}
        <nav class="mx-auto flex max-w-6xl gap-1 px-4 pb-2">
            @php
                $secciones = [
                    ['route' => 'admin.dashboard', 'label' => 'Tablero'],
                    ['route' => 'admin.restaurants.index', 'label' => 'Restaurantes'],
                    ['route' => 'admin.couriers.index', 'label' => 'Motorizados'],
                    ['route' => 'admin.orders.index', 'label' => 'Pedidos'],
                ];
            @endphp

            @foreach ($secciones as $seccion)
                @php $activa = request()->routeIs($seccion['route']); @endphp

                <a href="{{ route($seccion['route']) }}"
                   class="{{ $activa
                       ? 'bg-white text-navy'
                       : 'text-teal-soft hover:bg-white/10 hover:text-white' }} rounded-full px-4 py-2 text-sm font-semibold transition">
                    {{ $seccion['label'] }}
                </a>
            @endforeach
        </nav>
    </header>

    <main class="mx-auto max-w-6xl px-6 py-8">

        {{--
            El aviso de lo que acaba de pasar ("quedó creado", "quedó
            desactivado"). Se muestra una sola vez, porque el mensaje viaja en
            la sesión y se borra al mostrarlo.
        --}}
        @if (session('status'))
            <div class="mb-6 rounded-2xl bg-mint/20 px-5 py-4 text-sm font-semibold text-teal-deep">
                {{ session('status') }}
            </div>
        @endif

        {{--
            El aviso de que algo NO se pudo hacer ("ya está cerrado", "no se le
            puede quitar el motorizado"). Va en rojo y es tan importante como el
            verde: intervenir un pedido tiene reglas, y cuando se choca con una
            hay que decir por qué en vez de dejar el botón sin efecto.
        --}}
        @if (session('error'))
            <div class="mb-6 rounded-2xl bg-coral/15 px-5 py-4 text-sm font-semibold text-coral">
                {{ session('error') }}
            </div>
        @endif

        @yield('content')
    </main>

</body>
</html>
