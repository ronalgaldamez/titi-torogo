<?php

use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API movil de ToroGo (Flutter)
|--------------------------------------------------------------------------
|
| Rutas publicas:   login, register
| Rutas protegidas: todo lo que exige token -> middleware('auth:sanctum')
|
| Todas las rutas de este archivo ya llevan el prefijo /api automaticamente.
|
*/

Route::post('/login', [AuthController::class, 'login'])->name('api.login');

/*
 * Registro de clientes. Restaurante, Motorizado y Admin no se registran
 * solos: los da de alta el administrador desde el panel web.
 */
Route::post('/register', [AuthController::class, 'register'])->name('api.register');

/*
|--------------------------------------------------------------------------
| Rutas protegidas
|--------------------------------------------------------------------------
| Exigen el header:   Authorization: Bearer <token>
|
*/

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me'])->name('api.me');
});
