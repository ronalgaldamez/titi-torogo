@extends('layouts.public')
@section('content')
<div id="tl-torogo">
    <header class="tl-nav"><a class="tl-logo" href="{{ route('landing') }}" aria-label="ToroGo inicio">toro<span>go</span><b>.</b></a><a class="tl-text-button" href="{{ route('landing') }}">Volver a ToroGo <x-landing-icon name="arrow-left" /></a></header>
    <main class="tl-legal-page">
        <span class="tl-eyebrow">INFORMACIÓN DE TOROGO</span>
        <h1>{{ $policy['title'] }}</h1>
        <p class="tl-legal-status"><strong>Borrador para revisión · {{ config('legal.reviewed_at') }}</strong><br>Esta versión incorpora la información confirmada del proyecto. Los puntos pendientes están indicados; todavía no es una versión definitiva para el lanzamiento.</p>
        <nav class="tl-legal-nav" aria-label="Documentos de información">
            @foreach (['privacidad' => 'Privacidad', 'terminos' => 'Términos', 'cookies' => 'Cookies'] as $key => $title)
                <a href="{{ route('landing.legal', $key) }}" @if ($document === $key) aria-current="page" @endif>{{ $title }}</a>
            @endforeach
        </nav>
        <section><h2>Responsable y contacto</h2><p><strong>{{ config('legal.responsible') }}</strong>, operador de ToroGo, en Chalatenango, El Salvador. Yerba Digital identifica la marca de desarrollo; no se presenta como una sociedad constituida.</p><p>Consultas, privacidad y problemas con pedidos: <a href="mailto:{{ $content['contact_email'] }}">{{ $content['contact_email'] }}</a>. El domicilio de atención está pendiente de completar antes del lanzamiento.</p></section>
        @foreach ($policy['sections'] as $heading => $paragraphs)
            <section><h2>{{ $heading }}</h2>@foreach ($paragraphs as $paragraph)<p>{{ $paragraph }}</p>@endforeach</section>
        @endforeach
        <section><h2>Fuentes consultadas</h2><p><a href="https://www.jurisprudencia.gob.sv/DocumentosBoveda/D/2/2020-2029/2024/11/10660E.PDF">Ley para la Protección de Datos Personales, texto consolidado</a> y <a href="https://www.defensoria.gob.sv/obligaciones/">orientación de la Defensoría del Consumidor sobre obligaciones y comercio electrónico</a>. El contenido debe revisarse junto con la operación definitiva antes de su publicación final.</p></section>
        <a class="tl-primary" href="{{ route('landing') }}">Volver a ToroGo <x-landing-icon name="arrow-left" /></a>
    </main>
</div>
@endsection
