<?php

namespace App\Http\Middleware;

use App\Enums\UserRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Deja pasar solo a las cuentas de motorizado.
 *
 * Es mas corto que su hermano EnsureRestaurantAccount porque el motorizado no
 * tiene "ficha" aparte: el restaurante necesita una fila en 'restaurants' que
 * le arma el administrador, pero el motorizado es solo una cuenta con su
 * perfil. Aca alcanza con el rol.
 */
class EnsureCourierAccount
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->hasRole(UserRole::Courier)) {
            // 403 y no 401: el token sirve, el que no tiene permiso es el
            // perfil. Con 401 la app cerraria la sesion, que es justo lo que
            // NO queremos.
            return response()->json([
                'message' => 'Esta cuenta no es de motorizado.',
            ], Response::HTTP_FORBIDDEN);
        }

        return $next($request);
    }
}
