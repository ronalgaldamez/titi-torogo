<div id="tf-end">
    <section class="closing"><span class="eyebrow">{{ $content['closing_eyebrow'] }}</span><h2>{{ $content['closing_title'] }}<br><em>{{ $content['closing_accent'] }}</em></h2><a href="{{ route('web.order') }}" class="cta">{{ $content['closing_button'] }}<x-landing-icon name="arrow-up-right" /></a><p>{{ $content['closing_description'] }}</p><div class="doodles" aria-hidden="true"><x-landing-icon name="pizza" /><x-landing-icon name="hamburger" /><x-landing-icon name="coffee" /><x-landing-icon name="utensils" /></div></section>
    <footer>
        <div class="footer-main">
            <div class="brand"><div class="logo">toro<span>go</span><b>.</b></div><p>{{ $content['footer_description'] }}</p><span class="location"><x-landing-icon name="map-pin" />{{ $content['footer_location'] }}</span></div>
            <div><h3>CONOCÉ TOROGO</h3><nav class="links" aria-label="ToroGo"><a href="#historia">Somos ToroGo</a><a href="#como">Cómo funciona</a><a href="#sumate">Sumá tu negocio</a><a href="#sumate">Repartí con ToroGo</a></nav></div>
            <div><h3>INFORMACIÓN</h3><nav class="links" aria-label="Información y privacidad">
                @foreach (['privacy' => 'Privacidad', 'terms' => 'Términos y condiciones', 'cookies' => 'Cookies'] as $key => $title)
                    <button type="button" data-landing-dialog="tl-legal-{{ $key }}">{{ $title }}</button>
                @endforeach
                @if (! empty($content['contact_email']))
                    <a href="mailto:{{ $content['contact_email'] }}">Contacto</a>
                @else
                    <button type="button" data-landing-dialog="tl-footer-contact">Contacto</button>
                @endif
            </nav></div>
        </div>
        <div class="base"><span>© {{ now()->year }} ToroGo · Hecho en El Salvador.</span><button type="button" class="preferences-link" data-landing-dialog="tl-cookie-preferences"><x-landing-icon name="sliders" />Preferencias de cookies</button></div>
    </footer>
    @foreach (['privacy' => 'Privacidad', 'terms' => 'Términos y condiciones', 'cookies' => 'Cookies'] as $key => $title)
        <dialog id="tl-legal-{{ $key }}" aria-labelledby="tl-legal-title-{{ $key }}"><div class="dialog-head"><h3 id="tl-legal-title-{{ $key }}">{{ $title }}</h3><form method="dialog"><button class="close" aria-label="Cerrar"><x-landing-icon name="x" /></button></form></div><span class="draft">CONTENIDO EN PREPARACIÓN</span><p>{{ $content['legal_'.$key.'_notice'] }}</p><form method="dialog"><button class="done">Volver a ToroGo</button></form></dialog>
    @endforeach
    <dialog id="tl-cookie-preferences" aria-labelledby="tl-cookie-title"><div class="dialog-head"><h3 id="tl-cookie-title">Tus preferencias</h3><form method="dialog"><button class="close" aria-label="Cerrar"><x-landing-icon name="x" /></button></form></div><span class="draft">EN PREPARACIÓN</span><p>{{ $content['cookie_preferences_notice'] }}</p><form method="dialog"><button class="done">Entendido</button></form></dialog>
    <dialog id="tl-footer-contact" aria-labelledby="tl-footer-contact-title"><div class="dialog-head"><h3 id="tl-footer-contact-title">Contacto</h3><form method="dialog"><button class="close" aria-label="Cerrar"><x-landing-icon name="x" /></button></form></div><p>Estamos preparando nuestro canal de atención. Pronto publicaremos aquí cómo contactarnos.</p><form method="dialog"><button class="done">Volver a ToroGo</button></form></dialog>
</div>
