<?php

use App\Http\Controllers\Api\AddressController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CourierOrderController;
use App\Http\Controllers\Api\MenuController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\RestaurantController;
use App\Http\Controllers\Api\RestaurantOrderController;
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

/*
 * El detalle con el menu. Tambien publica, por lo mismo.
 *
 * Va DESPUES de /restaurants y no hay conflicto: son rutas distintas
 * ('/restaurants' y '/restaurants/{restaurant}').
 */
Route::get('/restaurants/{restaurant}', [RestaurantController::class, 'show'])
    ->name('api.restaurants.show');

// ---------------------------- Rutas protegidas -------------------------

/*
| Exigen el header:   Authorization: Bearer <token>
*/

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/me', [AuthController::class, 'me'])->name('api.me');
    Route::post('/logout', [AuthController::class, 'logout'])->name('api.logout');

    // ---------------------------- Direcciones ----------------------------

    /*
    | Las direcciones guardadas del cliente ("Mis direcciones" en la biblia, y
    | el paso "elegir entre guardadas" del checkout).
    |
    | Cada uno ve solo las suyas: las consultas salen de la relacion del
    | usuario, asi que la direccion de otro responde 404.
    */
    Route::get('/addresses', [AddressController::class, 'index'])
        ->name('api.addresses.index');

    Route::post('/addresses', [AddressController::class, 'store'])
        ->name('api.addresses.store');

    // El formulario manda la direccion completa.
    Route::put('/addresses/{address}', [AddressController::class, 'update'])
        ->name('api.addresses.update');

    Route::delete('/addresses/{address}', [AddressController::class, 'destroy'])
        ->name('api.addresses.destroy');

    // ------------------------------ Pedidos ------------------------------

    /*
    | Cualquier cuenta con sesion puede pedir: pedir NO es un privilegio de un
    | perfil. El dueno del restaurante tambien come, y el motorizado tambien.
    | Lo que cambia por perfil es lo que cada uno puede VER y HACER con el
    | pedido, y eso vive en las rutas de abajo.
    |
    | La clave contra el doble cobro viaja en el cuerpo ('idempotency_key'),
    | no en la URL: es parte del pedido, no una direccion.
    */
    Route::post('/orders', [OrderController::class, 'store'])
        ->name('api.orders.store');

    /*
    | Ver MIS pedidos. Las consultas salen de la relacion del usuario, asi que
    | cada uno ve solo los suyos: el pedido de otro responde 404.
    */
    Route::get('/orders', [OrderController::class, 'index'])
        ->name('api.orders.index');

    Route::get('/orders/{order}', [OrderController::class, 'show'])
        ->name('api.orders.show');
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

        Route::post('/menu/categories', [MenuController::class, 'storeCategory'])
            ->name('api.restaurant.menu.categories.store');

        Route::put('/menu/categories/{category}', [MenuController::class, 'updateCategory'])
            ->name('api.restaurant.menu.categories.update');

        // Borra la categoria, NO sus platos: los deja sin categoria.
        Route::delete('/menu/categories/{category}', [MenuController::class, 'destroyCategory'])
            ->name('api.restaurant.menu.categories.destroy');

        Route::post('/menu/products', [MenuController::class, 'storeProduct'])
            ->name('api.restaurant.menu.products.store');

        // El toggle de agotado. PATCH porque cambia UN campo del plato.
        Route::patch('/menu/products/{product}/availability', [MenuController::class, 'updateProductAvailability'])
            ->name('api.restaurant.menu.products.availability');

        // Editar el plato completo (el formulario de la app).
        Route::put('/menu/products/{product}', [MenuController::class, 'updateProduct'])
            ->name('api.restaurant.menu.products.update');

        // Borrado suave del plato.
        Route::delete('/menu/products/{product}', [MenuController::class, 'destroyProduct'])
            ->name('api.restaurant.menu.products.destroy');

        // ---------------------------- Pedidos ----------------------------

        // Sin ?status, devuelve los pedidos EN CURSO (el historial se pide
        // con ?status=delivered).
        Route::get('/orders', [RestaurantOrderController::class, 'index'])
            ->name('api.restaurant.orders.index');

        // Aceptar, rechazar, preparando, listo para recoger.
        // PATCH y no PUT: cambia UN campo del pedido, el estado.
        Route::patch('/orders/{order}', [RestaurantOrderController::class, 'updateStatus'])
            ->name('api.restaurant.orders.status');
    });

// ------------------------- App del motorizado --------------------------

/*
| Solo para cuentas de motorizado (ver EnsureCourierAccount).
|
| OJO con el orden de estas rutas: '/orders/available' va ANTES de
| '/orders/{order}'. Si estuviera despues, Laravel leeria "available" como el
| id de un pedido y respondería 404 buscando un pedido llamado "available".
*/
Route::middleware(['auth:sanctum', 'courier'])
    ->prefix('courier')
    ->group(function () {
        // "Disponible / No disponible".
        Route::patch('/availability', [CourierOrderController::class, 'updateAvailability'])
            ->name('api.courier.availability');

        // Los pedidos que YO llevo (tracking activo).
        Route::get('/orders', [CourierOrderController::class, 'index'])
            ->name('api.courier.orders.index');

        // Los que estan listos para recoger y sin repartidor, cerca de mi.
        Route::get('/orders/available', [CourierOrderController::class, 'available'])
            ->name('api.courier.orders.available');

        // Tomar el pedido. POST y no PATCH: no lo edita, me lo ASIGNA — y esa
        // asignacion puede pasar UNA sola vez.
        Route::post('/orders/{order}/take', [CourierOrderController::class, 'take'])
            ->name('api.courier.orders.take');

        // Recogido y entregado.
        Route::patch('/orders/{order}', [CourierOrderController::class, 'updateStatus'])
            ->name('api.courier.orders.status');
    });
