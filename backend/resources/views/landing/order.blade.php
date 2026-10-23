@extends('layouts.public')

@section('content')
<div id="tl-torogo">
    <header class="tl-nav"><a href="{{ route('landing') }}" class="tl-logo" aria-label="Volver a ToroGo">toro<span>go</span><b>.</b></a><a class="tl-text-button" href="{{ route('landing') }}">Volver al inicio <x-landing-icon name="arrow-left" /></a></header>
    <main class="tl-order-pending">
        <span class="tl-eyebrow">LO BUENO YA VIENE.</span>
        <h1>Tu próximo antojo.<br><em>También desde la web.</em></h1>
        <p>Estamos preparando los pedidos desde el navegador. Por ahora, esta página no permite crear pedidos.</p>
        <p>La app de ToroGo continúa funcionando con su catálogo y seguimiento habituales.</p>
        <a class="tl-primary" href="{{ route('landing') }}">Conocé ToroGo <x-landing-icon name="arrow-left" /></a>
    </main>
</div>
@endsection
