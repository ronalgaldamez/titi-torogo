<div id="tj-community">
    <section class="join" id="sumate">
        <div class="heading"><div><span class="eyebrow">{{ $content['join_eyebrow'] }}</span><h2>{{ $content['join_title'] }} <em>{{ $content['join_accent'] }}</em></h2></div><p>{{ $content['join_description'] }}</p></div>
        <div class="paths">
            @foreach (['restaurant' => ['food', 'store', 'utensils', 'PARA RESTAURANTES'], 'courier' => ['rider', 'motorbike', 'motorbike', 'PARA MOTORISTAS']] as $kind => $design)
                <article class="{{ $design[0] }}">
                    <span class="category"><x-landing-icon :name="$design[1]" />{{ $design[3] }}</span>
                    <x-landing-icon class="art" :name="$design[2]" />
                    <h3>{{ $content[$kind.'_title'] }}</h3>
                    <p>{{ $content[$kind.'_description'] }}</p>
                    <div class="benefits"><span>{{ $content[$kind.'_benefit_1'] }}</span><span>{{ $content[$kind.'_benefit_2'] }}</span></div>
                    <button type="button" class="tl-interest" data-interest="{{ $kind }}">{{ $content[$kind.'_button'] }}<x-landing-icon name="arrow-up-right" /></button>
                </article>
            @endforeach
        </div>
    </section>
    <section class="faq">
        <div class="faq-intro"><span class="bubble"><x-landing-icon name="messages" /></span><span class="eyebrow">{{ $content['faq_eyebrow'] }}</span><h2>{{ $content['faq_title'] }}<br><em>{{ $content['faq_accent'] }}</em></h2><p>{{ $content['faq_intro'] }}</p></div>
        <div>
            @for ($number = 1; $number <= 4; $number++)
                <details @if ($number === 1) open @endif><summary>{{ $content['faq_'.$number.'_question'] }}<x-landing-icon name="plus" /></summary><p>{{ $content['faq_'.$number.'_answer'] }}</p></details>
            @endfor
        </div>
    </section>
</div>
