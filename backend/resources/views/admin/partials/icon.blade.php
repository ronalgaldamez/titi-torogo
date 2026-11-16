@php
    $paths = [
        'dashboard' => 'M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z',
        'orders' => 'M6 3h12v18l-3-2-3 2-3-2-3 2z M9 7h6 M9 11h6 M9 15h3',
        'store' => 'M3 10h18l-2-7H5z M4 10v11h16V10 M9 21v-7h6v7',
        'bike' => 'M8 7h5l4 10 M5 17l5-10 M14 4h3 M8 4h3 M8 17a3 3 0 1 1-6 0 3 3 0 0 1 6 0 M22 17a3 3 0 1 1-6 0 3 3 0 0 1 6 0',
        'users' => 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2 M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0 M18 3a4 4 0 0 1 0 8 M22 21v-2a4 4 0 0 0-3-4',
        'grid' => 'M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z',
        'database' => 'M21 5c0 2-4 3-9 3S3 7 3 5s4-3 9-3 9 1 9 3 M3 5v14c0 2 4 3 9 3s9-1 9-3V5 M3 12c0 2 4 3 9 3s9-1 9-3',
        'settings' => 'M4 5h16 M4 12h16 M4 19h16 M8 2v6 M16 9v6 M10 16v6',
        'globe' => 'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0 M3 12h18 M12 3c5 5 5 13 0 18 M12 3c-5 5-5 13 0 18',
        'menu' => 'M3 6h18 M3 12h18 M3 18h18',
        'close' => 'M6 6l12 12 M6 18 18 6',
        'logout' => 'M9 3H3v18h6 M9 12h12 M17 8l4 4-4 4',
        'shield' => 'M12 3l9 4v5c0 5-9 10-9 10S3 17 3 12V7z M8 12l3 3 5-6',
    ];
@endphp
<svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="{{ $paths[$icon] ?? $paths['grid'] }}"/></svg>
