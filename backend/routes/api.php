<?php

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\MenuController;
use App\Http\Controllers\Api\RestaurantController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API movil de ToroGo (Flutter)
|--------------------------------------------------------------------------
|
| Todas las rutas de este archivo ya llevan el prefijo /api automaticamente.
|
*/

// ---------------------------- Autenticacion ----------------------------

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

// --------------------------- Home del cliente --------------------------

/*
 * Publica a proposito: mostrar los restaurantes ANTES de pedir registro
 * baja muchisimo la friccion — el usuario ve lo que hay y despues crea su
 * cuenta. Si preferis exigir sesion, agregale ->middleware('auth:sanctum').
 */
Route::get('/restaurants', [RestaurantController::class, 'index'])
    ->name('api.restaurants.index');

// ---------------------------- Rutas protegidas -------------------------

/*
| Exigen el header:   Authorization: Bearer <token>
*/

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me'])->name('api.me');
    Route::post('/logout', [AuthController::class, 'logout'])->name('api.logout');
});

// ------------------------ Panel del restaurante ------------------------

/*
| Solo para cuentas de restaurante con ficha creada. El middleware
| 'restaurant' hace las dos verificaciones (ver EnsureRestaurantAccount).
|
| OJO con el singular: /api/restaurant/... es EL restaurante de la sesion.
| /api/restaurants (plural) sigue siendo el catalogo publico del cliente.
| Confundirlos seria abrir el menu editable a cualquiera.
*/
Route::middleware(['auth:sanctum', 'restaurant'])
    ->prefix('restaurant')
    ->group(function () {
        Route::get('/menu', [MenuController::class, 'index'])
            ->name('api.restaurant.menu.index');
    });
