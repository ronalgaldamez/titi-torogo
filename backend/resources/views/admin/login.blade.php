<!DOCTYPE html>
<html lang="es" data-admin-theme="original">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Entrar · ToroGo</title>
    @include('partials.favicon')
    @vite(['resources/css/app.css'])
    @include('admin.partials.assets')
</head>
<body class="admin-app admin-login-page">
    <section class="admin-login-brand" aria-label="ToroGo Administración">
        @include('admin.partials.logo')
        <div class="admin-login-message"><span class="admin-overline">TODO EN SU LUGAR</span><h1>Una operación<br>bien llevada.</h1><p>Tu equipo, tus negocios y cada entrega. El control está de tu lado.</p></div>
        <footer>Hecho para mover lo nuestro.</footer>
    </section>
    <main class="admin-login-form-area">
        <div class="admin-login-appearance">@include('admin.partials.appearance')</div>
        <span class="admin-overline">BIENVENIDO DE NUEVO</span>
        <h2>Entrá a tu panel.</h2>
        <p>Administrá ToroGo desde donde estés.</p>
        @if ($errors->any())<div role="alert" class="admin-notice admin-notice-error mt-5">{{ $errors->first() }}</div>@endif
        <form method="POST" action="{{ route('login.attempt') }}" class="space-y-5" data-skip-confirm>
            @csrf
            <div><label for="email" class="mb-2 block text-sm font-semibold">Correo electrónico</label><input id="email" name="email" type="email" required autocomplete="username" value="{{ old('email') }}" class="w-full rounded-xl border px-4 py-3"></div>
            <div><label for="password" class="mb-2 block text-sm font-semibold">Contraseña</label><div class="admin-password-field"><input id="password" name="password" type="password" required autocomplete="current-password" class="w-full rounded-xl border px-4 py-3"><button type="button" id="admin-show-password" class="admin-password-toggle" aria-controls="password" aria-pressed="false">Mostrar</button></div></div>
            <label class="flex items-center gap-2 text-sm text-navy/70"><input type="checkbox" name="remember" value="1" class="h-4 w-4">Mantener la sesión abierta</label>
            <button type="submit" class="admin-button">Entrar al administrador</button>
        </form>
        <footer><span>Solo para administradores</span><span>El Salvador</span></footer>
    </main>
    <p id="admin-submit-status" class="admin-submit-status" role="status" aria-live="polite" hidden>Entrando. Esperá un momento…</p>
</body>
</html>
