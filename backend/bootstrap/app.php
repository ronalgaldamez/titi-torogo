<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

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
        /*
         * 404 limpio en la API.
         *
         * findOrFail (por ejemplo al tocar el plato de OTRO restaurante,
         * ver MenuController::updateProductAvailability) lanza
         * ModelNotFoundException. Sin esto, la app recibe la traza completa
         * de Laravel: rutas del servidor, lineas y nombres de clases. Con
         * APP_DEBUG=true sale todo; con APP_DEBUG=false igual se filtra el
         * nombre del modelo. Nada de eso le sirve a Flutter, y es
         * informacion del servidor que no queremos repartir.
         *
         * OJO CON LA CLASE: no se puede tipar en ModelNotFoundException.
         * Laravel convierte esa excepcion en NotFoundHttpException ANTES de
         * llamar a estos callbacks, asi que un callback tipado en
         * ModelNotFoundException NUNCA se ejecuta. Hay que tiparlo en la
         * clase a la que llega convertida.
         *
         * Se responde lo mismo exista o no el recurso, asi que tampoco sirve
         * para averiguar desde afuera que platos tiene otro restaurante.
         */
        $exceptions->render(function (NotFoundHttpException $e, Request $request) {
            if (! $request->is('api/*')) {
                // Fuera de la API no nos metemos: Laravel sigue con su
                // comportamiento normal (pagina de error web).
                return null;
            }

            return response()->json([
                'message' => 'No encontramos lo que buscabas.',
            ], 404);
        });
    })->create();
