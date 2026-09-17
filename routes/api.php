<?php

use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API movil de ToroGo (Flutter)
|--------------------------------------------------------------------------
|
| Rutas publicas:   login, register  (ambas con limite de intentos)
| Rutas protegidas: todo lo que exige token -> middleware('auth:sanctum')
|
| Todas las rutas de este archivo ya llevan el prefijo /api automaticamente.
|
*/

/*
 * throttle:login -> 5 intentos por minuto por correo + IP (ver AppServiceProvider).
 * Sin ese limite, alguien podria probar miles de contrasenas contra una cuenta.
 */
Route::post('/login', [AuthController::class, 'login'])
    ->middleware('throttle:login')
    ->name('api.login');

/*
 * Registro de clientes. Restaurante, Motorizado y Admin no se registran
 * solos: los da de alta el administrador desde el panel web.
 * throttle:register -> 10 cuentas por hora por IP.
 */
Route::post('/register', [AuthController::class, 'register'])
    ->middleware('throttle:register')
    ->name('api.register');

/*
|--------------------------------------------------------------------------
| Rutas protegidas
|--------------------------------------------------------------------------
| Exigen el header:   Authorization: Bearer <token>
|
*/

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me'])->name('api.me');
    Route::post('/logout', [AuthController::class, 'logout'])->name('api.logout');
});
