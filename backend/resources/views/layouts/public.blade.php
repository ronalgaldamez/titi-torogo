<!doctype html>
<html lang="es-SV">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="theme-color" content="#102e3c">
    <title>{{ $content['meta_title'] ?? 'ToroGo · Lo bueno está cerca' }}</title>
    <meta name="description" content="{{ $content['meta_description'] ?? 'ToroGo, restaurantes locales y entregas en Chalatenango.' }}">
    <link rel="stylesheet" href="{{ asset('css/landing.css') }}?v=8">
    <script src="{{ asset('js/landing.js') }}?v=3" defer></script>
</head>
<body>
    @yield('content')
</body>
</html>
