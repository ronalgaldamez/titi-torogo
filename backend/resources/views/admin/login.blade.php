{{--
    El login del panel.

    Es una pantalla aparte del layout: aca todavia no hay sesion, asi que no
    tiene sentido mostrarle el menu ni el boton de salir a alguien que no entro.
--}}
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Entrar · ToroGo</title>
    @vite(['resources/css/app.css'])
</head>
<body class="flex min-h-screen items-center justify-center bg-background px-6 text-navy antialiased">

    <div class="w-full max-w-sm">

        <div class="mb-6 text-center">
            <div class="text-3xl font-extrabold tracking-tight">
                <span class="text-teal">Toro</span><span class="text-navy">Go</span>
            </div>
            <p class="mt-1 text-sm text-navy/60">Panel de administración</p>
        </div>

        <div class="rounded-2xl bg-white p-6 shadow-sm">

            {{--
                Los errores van arriba del formulario y con el mismo texto que
                manda el controlador ("Las credenciales no coinciden" o "Esta
                cuenta no es de administrador"). No se traducen: se muestran tal
                cual, que es lo que la persona necesita leer.
            --}}
            @if ($errors->any())
                <div class="mb-4 rounded-xl bg-coral/10 px-4 py-3 text-sm font-medium text-coral">
                    {{ $errors->first() }}
                </div>
            @endif

            <form method="POST" action="{{ route('login.attempt') }}" class="space-y-4">
                @csrf

                <div>
                    <label for="email" class="mb-1 block text-sm font-semibold">Correo</label>
                    <input id="email" name="email" type="email" required autofocus
                           value="{{ old('email') }}"
                           class="w-full rounded-xl border border-navy/15 px-4 py-2.5 outline-none transition focus:border-teal focus:ring-2 focus:ring-teal/20">
                </div>

                <div>
                    <label for="password" class="mb-1 block text-sm font-semibold">Contraseña</label>
                    <input id="password" name="password" type="password" required
                           class="w-full rounded-xl border border-navy/15 px-4 py-2.5 outline-none transition focus:border-teal focus:ring-2 focus:ring-teal/20">
                </div>

                <label class="flex items-center gap-2 text-sm text-navy/70">
                    <input type="checkbox" name="remember" value="1"
                           class="h-4 w-4 rounded border-navy/20 text-teal focus:ring-teal/30">
                    Mantener la sesión abierta
                </label>

                <button type="submit"
                        class="w-full rounded-xl bg-teal px-4 py-3 font-bold text-white transition hover:bg-teal-deep">
                    Entrar
                </button>
            </form>
        </div>

        <p class="mt-4 text-center text-xs text-navy/50">
            Solo la cuenta del administrador puede entrar a este panel.
        </p>
    </div>

</body>
</html>
