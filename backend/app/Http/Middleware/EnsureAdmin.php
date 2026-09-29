<?php

namespace App\Http\Middleware;

use App\Enums\UserRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Deja entrar al panel SOLO a la cuenta del administrador.
 *
 * Es la misma idea que EnsureRestaurantAccount y EnsureCourierAccount: el
 * perfil se verifica contra la BASE, nunca contra lo que diga el navegador. Un
 * dueno de restaurante que se loguee con sus credenciales es un usuario valido,
 * pero aca se lo frena.
 *
 * Devuelve 403 y no un redirect al login a proposito: si alguien llega hasta
 * aca es porque YA tiene sesion abierta, asi que mandarlo al login no arregla
 * nada y encima le esconde el motivo.
 */
class EnsureAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (! $user || ! $user->hasRole(UserRole::Admin)) {
            abort(403, 'Este panel es solo para el administrador.');
        }

        return $next($request);
    }
}
