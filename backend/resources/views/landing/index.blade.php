@extends('layouts.public')
@section('content')
<div id="tl-torogo" aria-label="Landing de ToroGo y acceso a pedidos">
 <div class="tl-landing">
  <header class="tl-nav"><a class="tl-logo" href="#inicio" aria-label="ToroGo inicio">toro<span>go</span><b>.</b></a><nav aria-label="Navegación de ToroGo"><a href="#historia" >Somos ToroGo</a><a href="#como" >Cómo funciona</a><a href="#sumate" >Sumate</a></nav><a href="{{ route('web.order') }}" class="tl-order-action tl-nav-cta">Pedí ahora<x-landing-icon name="arrow-up-right" /></a></header>
  <main>
   <section class="tl-hero" id="inicio"><div class="tl-hero-text"><span class="tl-eyebrow"><span></span>{{ $content['hero_eyebrow'] }}</span><h1>{{ $content['hero_title'] }}<br><em>{{ $content['hero_accent'] }}</em></h1><p>{{ $content['hero_description'] }}</p><div class="tl-hero-actions"><a href="{{ route('web.order') }}" class="tl-primary tl-order-action">{{ $content['hero_button'] }}<x-landing-icon name="arrow-right" /></a><a href="#como" class="tl-text-button">¿Cómo funciona?<x-landing-icon name="arrow-down" /></a></div><span class="tl-hero-note"><x-landing-icon name="globe" />{{ $content['hero_note'] }}</span>@include('landing.app-stores')</div><div class="tl-hero-photo"><img src="{{ $images['hero'] }}" alt="{{ $content['hero_image_alt'] }}"><span class="tl-photo-label">{{ $content['hero_photo_label'] }}<br><b>{{ $content['hero_photo_caption'] }}</b></span><div class="tl-coral-sticker"><x-landing-icon name="shopping-bag" /><b>{{ $content['hero_sticker'] }}</b></div></div></section>
   @include('landing.brand-line')
   @include('landing.story')
   @include('landing.how')
   @include('landing.local-banner')
   @include('landing.community')
  </main>
  @include('landing.ending')
 </div>

@include('landing.contact')
</div>
@endsection
