<link rel="stylesheet" href="{{ asset('css/admin.css') }}?v={{ filemtime(public_path('css/admin.css')) }}">
<script src="{{ asset('js/admin.js') }}?v={{ filemtime(public_path('js/admin.js')) }}" defer></script>
<script>try { const theme = localStorage.getItem('torogo-admin-theme'); if (['original', 'black', 'white'].includes(theme)) document.documentElement.dataset.adminTheme = theme; } catch {}</script>
