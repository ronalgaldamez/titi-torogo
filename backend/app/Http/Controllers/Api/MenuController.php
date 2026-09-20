<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MenuCategoryResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * La gestion del menu: lo que el restaurante ve y edita de su propia carta.
 *
 * Ninguna accion de aqui recibe un restaurant_id. El restaurante sale SIEMPRE
 * de la sesion (ver EnsureRestaurantAccount), asi que es imposible pedir o
 * tocar el menu de otro cambiando un numero en la URL. Es la misma regla que
 * ya se aplico con 'role' y con 'user_id': el servidor decide, no el cliente.
 */
class MenuController extends Controller
{
    /**
     * GET /api/restaurant/menu
     *
     * El menu completo: categorias con sus productos adentro.
     *
     * Trae TAMBIEN los productos agotados (is_available = false). Es al reves
     * que la carta publica a proposito: el cliente no debe ver lo que no hay,
     * pero el restaurante necesita verlo para volver a activarlo.
     */
    public function index(Request $request): JsonResponse
    {
        // El middleware ya cargo la relacion, asi que esto no vuelve a
        // consultar la base: Eloquent la tiene guardada en el mismo modelo.
        $categories = $request->user()->restaurant
            ->menuCategories()  // ya vienen ordenadas por sort_order
            ->with('products')  // products ya viene ordenada por sort_order
            ->get();

        return response()->json([
            'categories' => MenuCategoryResource::collection($categories),
        ]);
    }
}
