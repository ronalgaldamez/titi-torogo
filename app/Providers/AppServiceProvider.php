<?php

namespace App\Providers;

use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Por defecto Laravel envuelve los API Resources en una clave "data":
        //     GET /api/me  ->  { "data": { "id": 1, ... } }
        //
        // El problema aparece cuando un recurso va dentro de un sobre propio:
        // nuestro login devuelve { token, user }, y ahi el "user" sale SIN
        // envoltorio. Resultado: dos formatos distintos para el mismo dato,
        // y Flutter tendria que parsear cada endpoint de una forma.
        //
        // ToroGo usa UN SOLO formato en toda la API:
        //     GET /api/me  ->  { "id": 1, ... }
        JsonResource::withoutWrapping();
    }
}
