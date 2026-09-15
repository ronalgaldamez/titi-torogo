<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Cross-Origin Resource Sharing (CORS)
    |--------------------------------------------------------------------------
    |
    | Aqui se define que origenes pueden llamar a la API desde un navegador.
    |
    | ToroGo lo necesita por dos razones:
    |
    |   1) Durante el desarrollo vamos a correr la app Flutter en el navegador
    |      (Edge) para verla rapido. La app corre en un puerto y la API en el
    |      8080: son origenes distintos, y sin esto el navegador bloquea las
    |      peticiones antes de que salgan.
    |
    |   2) El panel de administracion, si algun dia vive en otro dominio.
    |
    | '*' es seguro en esta API porque la autenticacion es por token Bearer
    | (header Authorization) y NO por cookies: con 'supports_credentials' en
    | false, un sitio ajeno no puede usar la sesion de nadie.
    |
    | En produccion igual conviene restringir 'allowed_origins' a los dominios
    | reales de la app y del panel.
    |
    */

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => ['*'],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 0,

    'supports_credentials' => false,

];
