<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // Toda la API responde JSON, sin depender de que el cliente mande
        // el header Accept. Ver App\Http\Middleware\ForceJsonResponse.
        $middleware->api(prepend: [
            \App\Http\Middleware\ForceJsonResponse::class,
        ]);

        // Alias cortos para las rutas. Se declaran aqui, una sola vez, y en
        // routes/api.php se escriben por nombre ('restaurant') en vez de
        // repetir el nombre completo de la clase en cada grupo.
        $middleware->alias([
            'restaurant' => \App\Http\Middleware\EnsureRestaurantAccount::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
