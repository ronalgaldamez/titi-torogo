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
    </header>

    <main class="mx-auto max-w-6xl px-6 py-8">
        @yield('content')
    </main>

</body>
</html>
