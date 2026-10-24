@props(['name'])
@php
    $paths = [
        'arrow-up-right' => ['M7 17 17 7M7 7h10v10'],
        'arrow-right' => ['M5 12h14m-6-6 6 6-6 6'],
        'arrow-left' => ['M19 12H5m6-6-6 6 6 6'],
        'arrow-down' => ['M12 5v14m-6-6 6 6 6-6'],
        'plus' => ['M12 5v14M5 12h14'],
        'sliders' => ['M3 6h4m4 0h10M3 18h10m4 0h4M7 3v6m4-3H7m6 9v6m4-3h-4'],
        'messages' => ['M21 11a2 2 0 0 1-2 2H9l-5 4V5a2 2 0 0 1 2-2h13a2 2 0 0 1 2 2Z', 'M9 17v2a2 2 0 0 0 2 2h7l4 2V9'],
        'heart' => ['M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.8-8.6a5.5 5.5 0 0 0 0-7.8Z'],
        'play' => ['m6 3 15 9-15 9Z'],
        'apple' => ['M12 6c0-3 2-4 4-4 0 3-2 4-4 4', 'M12 7c-3-2-8-1-8 5 0 5 3 10 5 10 1 0 2-1 3-1s2 1 3 1c2 0 5-5 5-10 0-6-5-7-8-5Z'],
        'x' => ['m6 6 12 12M6 18 18 6'],
        'globe' => ['M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0M3 12h18M12 3c4 5 4 13 0 18-4-5-4-13 0-18'],
        'shopping-bag' => ['m6 2-3 4v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4ZM3 6h18M8 10a4 4 0 0 0 8 0'],
        'map-pin' => ['M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 1 1 16 0ZM15 10a3 3 0 1 1-6 0 3 3 0 0 1 6 0'],
        'utensils' => ['M4 2v7a3 3 0 0 0 6 0V2M7 2v20M20 2c-4 4-4 10 0 10V2Zm0 10v10'],
        'utensils-crossed' => ['m3 3 18 18M6 2l4 4-4 4-4-4m16-4c-5 2-6 7-3 10L5 22m10-10 7-7'],
        'motorbike' => ['M10 17a4 4 0 1 1-8 0 4 4 0 0 1 8 0Zm12 0a4 4 0 1 1-8 0 4 4 0 0 1 8 0ZM6 17l4-7h5l3 7M9 10l-1-3H5m8 0h3l2 10M10 17h4'],
        'store' => ['M3 10V6l2-4h14l2 4v4M3 6h18M3 10a3 3 0 0 0 6 0 3 3 0 0 0 6 0 3 3 0 0 0 6 0M4 13v9h16v-9M9 22v-7h6v7'],
        'sparkles' => ['m12 3 2.7 6.3L21 12l-6.3 2.7L12 21l-2.7-6.3L3 12l6.3-2.7ZM20 2v4m-2-2h4'],
        'pizza' => ['M15 2c3 1 5 3 7 7L3 22 15 2ZM13 5c3 1 5 3 6 6M12 12h.01M8 17h.01'],
        'hamburger' => ['M3 9h18C20 1 4 1 3 9Zm-1 4h20M3 17h18v2a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2Z'],
        'coffee' => ['M18 8h2a3 3 0 1 1 0 6h-2M3 8h15v9a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4ZM6 2v2m4-2v2m4-2v2'],
    ];
@endphp
<svg {{ $attributes }} width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
    @foreach ($paths[$name] ?? $paths['arrow-right'] as $path)<path d="{{ $path }}" />@endforeach
</svg>
