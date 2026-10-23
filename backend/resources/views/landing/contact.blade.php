<dialog class="tl-contact-dialog" aria-labelledby="landing-contact-title">
    <form method="dialog"><button class="tl-close" aria-label="Cerrar"><x-landing-icon name="x" /></button></form>
    <span class="tl-eyebrow">CREZCAMOS CERCA.</span>
    <h2 id="landing-contact-title" class="tl-dialog-title">Sumate a ToroGo</h2>
    <p class="tl-dialog-copy"></p>
    @if (! empty($content['contact_email']))
        <p>Escribinos y contanos cómo te gustaría sumarte.</p>
        <a class="tl-dialog-done" href="mailto:{{ $content['contact_email'] }}">{{ $content['contact_email'] }} <x-landing-icon name="arrow-up-right" /></a>
    @else
        <p>Estamos preparando la incorporación de nuevos negocios y motoristas. Pronto publicaremos aquí cómo contactarnos.</p>
    @endif
    <form method="dialog"><button class="tl-dialog-done">Volver a explorar <x-landing-icon name="arrow-right" /></button></form>
</dialog>
