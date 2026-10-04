<?php

use App\Http\Controllers\Admin\AuthController;
use App\Http\Controllers\Admin\CourierController;
use App\Http\Controllers\Admin\DashboardController;
use App\Http\Controllers\Admin\RestaurantController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Panel de administracion (web)
|--------------------------------------------------------------------------
|
| Es la ultima pieza del MVP (PASO 7 de la biblia).
|
| A diferencia de la API —que se autentica con tokens de Sanctum, porque la
| consume una app movil— el panel usa la SESION de Laravel: es una pagina web
| que se abre en el navegador de la compu, no en el telefono.
|
*/

// La raiz lleva al panel. El sitio publico todavia no existe, y la pantalla de
// bienvenida de Laravel no le sirve a nadie.
Route::redirect('/', '/admin');

Route::prefix('admin')->group(function (): void {
    // ---------------------- Sin sesion: el login ----------------------

    Route::middleware('guest')->group(function (): void {
        // OJO CON EL NOMBRE: es 'login' a secas y no 'admin.login' a proposito.
        // El middleware 'auth' de Laravel redirige a la ruta llamada 'login'
        // cuando alguien sin sesion entra a una ruta protegida, y busca
        // exactamente ese nombre.
        Route::get('/login', [AuthController::class, 'showLogin'])->name('login');

        // 10 intentos por minuto por correo + IP. Sin esto, alguien podria
        // probar miles de contrasenas contra la cuenta del administrador.
        Route::post('/login', [AuthController::class, 'login'])
            ->middleware('throttle:10,1')
            ->name('login.attempt');
    });

    // ---------------------- Con sesion: el panel ----------------------

    Route::middleware(['auth', 'admin'])->group(function (): void {
        Route::get('/', [DashboardController::class, 'index'])
            ->name('admin.dashboard');

        Route::post('/logout', [AuthController::class, 'logout'])
            ->name('admin.logout');

        // ------------------------- Restaurantes -------------------------

        Route::get('/restaurantes', [RestaurantController::class, 'index'])
            ->name('admin.restaurants.index');
        Route::get('/restaurantes/crear', [RestaurantController::class, 'create'])
            ->name('admin.restaurants.create');
        Route::post('/restaurantes', [RestaurantController::class, 'store'])
            ->name('admin.restaurants.store');
        Route::get('/restaurantes/{restaurant}/editar', [RestaurantController::class, 'edit'])
            ->name('admin.restaurants.edit');
        Route::put('/restaurantes/{restaurant}', [RestaurantController::class, 'update'])
            ->name('admin.restaurants.update');

        // Activar/desactivar: un POST y no un PATCH porque es un boton de un
        // formulario del navegador, sin JavaScript de por medio.
        Route::post('/restaurantes/{restaurant}/activar', [RestaurantController::class, 'toggle'])
            ->name('admin.restaurants.toggle');

        // -------------------------- Motorizados --------------------------

        Route::get('/motorizados', [CourierController::class, 'index'])
            ->name('admin.couriers.index');
        Route::get('/motorizados/crear', [CourierController::class, 'create'])
            ->name('admin.couriers.create');
        Route::post('/motorizados', [CourierController::class, 'store'])
            ->name('admin.couriers.store');
        Route::get('/motorizados/{courier}/editar', [CourierController::class, 'edit'])
            ->name('admin.couriers.edit');
        Route::put('/motorizados/{courier}', [CourierController::class, 'update'])
            ->name('admin.couriers.update');
        Route::post('/motorizados/{courier}/activar', [CourierController::class, 'toggle'])
            ->name('admin.couriers.toggle');
    });
});
