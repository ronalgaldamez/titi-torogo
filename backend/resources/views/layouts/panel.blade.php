<!DOCTYPE html>
<html lang="es" data-admin-theme="original">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Panel') · ToroGo</title>
    @include('partials.favicon')
    @vite(['resources/css/app.css'])
    @include('admin.partials.assets')
</head>
<body class="admin-app">
    @php
        $sections = [
            ['admin.dashboard', 'Tablero', 'dashboard'],
            ['admin.orders.*', 'Pedidos', 'orders'],
            ['admin.restaurants.*', 'Restaurantes', 'store'],
            ['admin.couriers.*', 'Motorizados', 'bike'],
            ['admin.customers.*', 'Clientes', 'users'],
            ['admin.categories.*', 'Categorías', 'grid'],
            ['admin.backups.*', 'Respaldos', 'database'],
            ['admin.settings.*', 'Configuración', 'settings'],
            ['admin.landing.*', 'Página web', 'globe'],
        ];
        $currentSection = collect($sections)->first(fn ($section) => request()->routeIs($section[0]));
        $backupResult = \App\Models\Backup::whereIn('status', ['succeeded', 'failed'])->latest('id')->first();
    @endphp
    <button type="button" class="admin-menu-shade" data-menu-close aria-label="Cerrar menú" hidden></button>
    <aside class="admin-sidebar" id="admin-sidebar" aria-label="Menú principal">
        <div class="admin-brand-row">
            <a href="{{ route('admin.dashboard') }}" class="admin-brand" aria-label="ToroGo, inicio del administrador">@include('admin.partials.logo')</a>
            <button type="button" class="admin-icon-button admin-menu-close" data-menu-close aria-label="Cerrar menú">@include('admin.partials.icon', ['icon' => 'close'])</button>
        </div>
        <span class="admin-nav-label">OPERACIÓN</span>
        <nav>
            @foreach ($sections as [$pattern, $label, $icon])
                @php $route = str_replace('.*', '.index', $pattern); if ($pattern === 'admin.landing.*') $route = 'admin.landing.edit'; @endphp
                <a href="{{ route($route) }}" class="admin-nav-item" @if(request()->routeIs($pattern)) aria-current="page" @endif>
                    @include('admin.partials.icon', ['icon' => $icon])<span>{{ $label }}</span>
                </a>
            @endforeach
        </nav>
        <div class="admin-sidebar-footer">
            <div class="admin-account"><span class="admin-avatar">{{ mb_substr(auth()->user()->name, 0, 1) }}</span><span>{{ auth()->user()->name }}<small>Administrador</small></span></div>
            <form method="POST" action="{{ route('admin.logout') }}" data-confirm="Cerrarás la sesión del administrador en este dispositivo.">
                @csrf
                <button type="submit" class="admin-logout">@include('admin.partials.icon', ['icon' => 'logout'])Cerrar sesión</button>
            </form>
        </div>
    </aside>
    <div class="admin-workspace">
        <header class="admin-topbar">
            <div class="admin-topbar-start">
                <button type="button" class="admin-icon-button admin-menu-open" id="admin-menu-open" aria-controls="admin-sidebar" aria-expanded="false" aria-label="Abrir menú">@include('admin.partials.icon', ['icon' => 'menu'])</button>
                <span class="admin-breadcrumb">Administración <span>/</span> <strong>{{ $currentSection[1] ?? 'Panel' }}</strong></span>
                <a href="{{ route('admin.dashboard') }}" class="admin-mobile-logo" aria-label="ToroGo, tablero">@include('admin.partials.logo', ['compact' => true])</a>
            </div>
            @include('admin.partials.appearance')
        </header>
        <main class="admin-content" id="admin-content">
            @if (session('status'))<div role="status" class="admin-notice admin-notice-success">{{ session('status') }}</div>@endif
            @if (session('error'))<div role="alert" class="admin-notice admin-notice-error">{{ session('error') }}</div>@endif
            @if ($backupResult?->status === 'failed')
                <div role="alert" class="admin-notice admin-notice-error">Falló el último respaldo. <a class="underline" href="{{ route('admin.backups.index') }}">Revisar historial y reintentar</a>.</div>
            @endif
            @yield('content')
        </main>
        <footer class="admin-footer"><span>ToroGo · Administración</span><span>Hora de El Salvador</span></footer>
    </div>
    @include('admin.partials.confirmation')
</body>
</html>
