<section class="tl-how tl-section tl-how-interactive" id="como">
    <div class="tl-heading"><div><span class="tl-eyebrow">{{ $content['how_eyebrow'] }}</span><h2>{{ $content['how_title'] }} <em>{{ $content['how_accent'] }}</em></h2></div><p>{{ $content['how_description'] }}</p></div>
    <div class="tl-steps" aria-label="Explorá cómo funciona ToroGo">
        @foreach (['map-pin', 'utensils', 'motorbike'] as $icon)
            @php($step = $loop->iteration)
            <article>
                <button type="button" class="tl-step-trigger" aria-pressed="{{ $loop->first ? 'true' : 'false' }}" aria-controls="tl-step-example" data-step-label="{{ $content['step_'.$step.'_label'] }}" data-step-example="{{ $content['step_'.$step.'_example'] }}">
                    <span class="tl-step-top"><span>0{{ $step }}</span><x-landing-icon :name="$icon" /></span>
                    <span class="tl-step-title">{{ $content['step_'.$step.'_title'] }}</span>
                    <span class="tl-step-description">{{ $content['step_'.$step.'_description'] }}</span>
                </button>
            </article>
        @endforeach
    </div>
    <div class="tl-step-example" id="tl-step-example" aria-live="polite" aria-atomic="true">
        <span class="tl-step-example-icon"><x-landing-icon name="shopping-bag" /></span>
        <div><small>{{ $content['step_1_label'] }}</small><strong>{{ $content['step_1_example'] }}</strong></div>
        <x-landing-icon name="arrow-up-right" />
    </div>
    <div class="tl-how-bottom"><a href="{{ route('web.order') }}" class="tl-primary">{{ $content['how_button'] }}<x-landing-icon name="arrow-right" /></a><p>{{ $content['hero_note'] }}</p></div>
</section>
