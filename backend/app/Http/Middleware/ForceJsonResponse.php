<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Fuerza que TODA peticion a /api/* se trate como JSON.
 *
 * Sin esto, Laravel mira el header "Accept" del cliente. Si no viene, cree
 * que es un navegador y ante un error de validacion devuelve un redirect
 * 302 hacia una pagina HTML, en vez de un 422 con el detalle del error.
 *
 * Eso es un footgun para una API: cualquier cliente que olvide el header
 * recibe HTML donde esperaba JSON, y encima con un codigo 302 que no dice
 * nada. Con los 4 perfiles y un panel de admin por venir, es cuestion de
 * tiempo que a alguien le pase.
 *
 * Aqui lo forzamos una sola vez, para toda la API.
 */
class ForceJsonResponse
{
    public function handle(Request $request, Closure $next): Response
    {
        $request->headers->set('Accept', 'application/json');

        return $next($request);
    }
}
