<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateRestaurantStatusRequest;
use App\Http\Resources\RestaurantResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * El estado del local: abierto/cerrado y "muy ocupado".
 *
 * Es el "Dashboard" que la biblia le pide al perfil del restaurante, y no es un
 * adorno: CERRAR el local es lo unico que hace que deje de recibir pedidos que
 * no puede preparar. El backend ya lo respeta en los dos lados:
 *
 *   - el cliente deja de verlo en el Home (RestaurantController::index filtra
 *     por is_open),
 *   - y si igual llega un pedido, se rechaza (OrderController::openRestaurant).
 *
 * "Muy ocupado" es otra cosa: no cierra nada, alarga el tiempo de entrega un
 * 50% (ver Restaurant::estimatedDeliveryMinutes) para no prometer lo que la
 * cocina no puede cumplir.
 *
 * El restaurante sale SIEMPRE de la sesion (ver EnsureRestaurantAccount), asi
 * que ningun endpoint de aca lleva un id por parametro.
 */
class RestaurantStatusController extends Controller
{
    /**
     * GET /api/restaurant/status
     *
     * El estado de AHORA.
     *
     * Se pregunta al abrir el dashboard en vez de guardarlo en el telefono: el
     * estado que importa es el del servidor, que es el mismo que ve el cliente.
     */
    public function show(Request $request): JsonResponse
    {
        return response()->json([
            'restaurant' => new RestaurantResource($request->user()->restaurant),
        ]);
    }

    /**
     * PATCH /api/restaurant/status
     *
     * Cambia los dos interruptores y devuelve como quedo TODO, no como creiamos
     * que iba a quedar.
     *
     * PATCH y no PUT: se cambian dos campos del restaurante, no se reemplaza el
     * restaurante entero (el nombre, la direccion y los horarios no se tocan
     * desde aca).
     */
    public function update(UpdateRestaurantStatusRequest $request): JsonResponse
    {
        $restaurant = $request->user()->restaurant;

        // Campo por campo, como en todo el proyecto: asi ningun campo que no
        // esperamos puede colarse por el cuerpo de la peticion.
        $restaurant->is_open = $request->validated('is_open');
        $restaurant->is_busy = $request->validated('is_busy');
        $restaurant->save();

        return response()->json([
            'restaurant' => new RestaurantResource($restaurant),
        ]);
    }
}
