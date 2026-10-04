<?php

namespace App\Http\Middleware;

use App\Enums\UserRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Deja pasar solo a las cuentas de restaurante que YA tienen su ficha.
 *
 * Son tres condiciones, y las tres importan:
 *
 *   1. role = Restaurant          -> es el perfil correcto
 *   2. existe fila en restaurants -> el administrador ya le armo la ficha
 *   3. la ficha esta ACTIVA       -> el administrador no lo dio de baja
 *
 * Con una sola no alcanza. Un usuario con role=Restaurant y sin ficha
 * entraria a un panel vacio que no puede llenar; una cuenta de otro perfil
 * con ficha (hoy imposible, manana no sabemos) entraria al panel de otro; y un
 * local DESACTIVADO seguiria viendo sus pedidos como si nada, con lo que el
 * boton del panel seria media mentira.
 *
 * Se aplica a TODAS las rutas del panel del restaurante (menu, pedidos,
 * dashboard). Por eso es middleware y no una verificacion repetida en cada
 * controlador: se escribe una vez y no se puede olvidar en el proximo.
 */
class EnsureRestaurantAccount
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->hasRole(UserRole::Restaurant) || $user->restaurant === null) {
            // 403 y no 401: el token es valido, el que no tiene permiso es
            // este perfil. Con 401 la app cerraria la sesion y lo mandaria
            // al login, que es justo lo que NO queremos.
            return response()->json([
                'message' => 'Esta cuenta no tiene un restaurante asignado.',
            ], Response::HTTP_FORBIDDEN);
        }

        if (! $user->restaurant->is_active) {
            // Tampoco es 401: la sesion sigue siendo valida, lo que pasa es que
            // el local esta dado de baja. La app muestra el mensaje tal cual,
            // asi el dueno entiende que no es un problema de su telefono.
            return response()->json([
                'message' => 'Tu local está desactivado. Hablá con el administrador de ToroGo.',
            ], Response::HTTP_FORBIDDEN);
        }

        return $next($request);
    }
}
