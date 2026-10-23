<section class="tl-terra" aria-label="{{ $content['local_title'] }} {{ $content['local_accent'] }}">
    <img src="{{ $images['local'] }}" alt="{{ $content['local_image_alt'] }}" loading="lazy">
    <div class="tl-terra-wash" aria-hidden="true"></div>
    <div class="tl-terra-copy">
        <span class="tl-eyebrow">{{ $content['local_eyebrow'] }}</span>
        <h2>{{ $content['local_title'] }}<br><em>{{ $content['local_accent'] }}</em></h2>
        <p>{{ $content['local_description'] }}</p>
        <a href="{{ route('web.order') }}" class="tl-terra-button">{{ $content['local_button'] }}<x-landing-icon name="arrow-up-right" /></a>
    </div>
    <span class="tl-terra-seal"><x-landing-icon name="heart" />{{ $content['local_seal'] }}</span>
</section>
