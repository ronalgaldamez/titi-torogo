<section class="tl-story tl-section tl-story-visual" id="historia">
    <div>
        <span class="tl-eyebrow">{{ $content['story_eyebrow'] }}</span>
        <h2>{{ $content['story_title'] }}<br><em>{{ $content['story_accent'] }}</em></h2>
        <div class="tl-story-copy"><p>{{ $content['story_intro'] }}</p><p>{{ $content['story_description'] }}</p></div>
        <a href="#como" class="tl-inline-order">{{ $content['story_button'] }}<x-landing-icon name="arrow-down" /></a>
    </div>
    <div class="tl-story-photo">
        <img src="{{ $images['story'] }}" alt="{{ $content['story_image_alt'] }}" loading="lazy">
        <span class="tl-story-tag"><x-landing-icon name="heart" />{{ $content['story_tag'] }}</span>
        <div class="tl-story-caption"><span>{{ $content['story_photo_label'] }}</span><strong>{{ $content['story_photo_caption'] }}</strong></div>
    </div>
</section>
