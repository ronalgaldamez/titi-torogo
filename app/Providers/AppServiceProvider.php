<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Str;

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

        $this->configureRateLimiting();
    }

    /**
     * Limites de intentos.
     *
     * El AGENDS lo pide explicitamente: "Rate limiting: Prevenir ataques de
     * fuerza bruta". Sin esto, /api/login acepta intentos infinitos y alguien
     * podria probar miles de contrasenas contra la cuenta del administrador.
     */
    private function configureRateLimiting(): void
    {
        // LOGIN: 5 intentos por minuto.
        //
        // La clave combina el correo con la IP a proposito:
        //   - solo por correo -> un atacante podria BLOQUEAR la cuenta de otra
        //     persona mandando intentos fallidos desde cualquier lado.
        //   - solo por IP     -> le bastaria rotar IPs para seguir probando.
        // Juntos, cada combinacion lleva su propio contador.
        RateLimiter::for('login', function (Request $request) {
            $email = Str::transliterate(Str::lower((string) $request->input('email')));

            return Limit::perMinute(5)->by($email.'|'.$request->ip());
        });

        // REGISTRO: 10 cuentas por hora por IP. Evita que alguien cree miles
        // de cuentas falsas para ensuciar la base de datos.
        RateLimiter::for('register', function (Request $request) {
            return Limit::perHour(10)->by($request->ip());
        });
    }
}
