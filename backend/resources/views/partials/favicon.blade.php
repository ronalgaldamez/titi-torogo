{{--
    Favicon de ToroGo.

    Vive aparte porque el <head> se escribe en tres vistas: la landing, el
    panel y el login del panel. Asi el icono se cambia en UN solo lugar.
--}}
<link rel="icon" href="{{ asset('favicon.ico') }}" sizes="48x48">
<link rel="icon" href="{{ asset('favicon.svg') }}" type="image/svg+xml">
<link rel="apple-touch-icon" href="{{ asset('apple-touch-icon.png') }}">
