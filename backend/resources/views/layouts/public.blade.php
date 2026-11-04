<!doctype html>
<html lang="es-SV">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#102e3c">
    <link rel="icon" href="{{ asset('favicon.ico') }}" sizes="48x48">
    <link rel="icon" href="{{ asset('favicon.svg') }}" type="image/svg+xml">
    <link rel="apple-touch-icon" href="{{ asset('apple-touch-icon.png') }}">
    <title>{{ $content['meta_title'] ?? 'ToroGo · Lo bueno está cerca' }}</title>
    <meta name="description" content="{{ $content['meta_description'] ?? 'ToroGo, restaurantes locales y entregas en Chalatenango.' }}">
    <link rel="stylesheet" href="{{ asset('css/landing.css') }}?v=9">
    <script src="{{ asset('js/landing.js') }}?v=3" defer></script>
</head>
<body>
    @yield('content')
</body>
</html>
