<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

/**
 * Autenticacion de la API movil.
 *
 * Los 4 perfiles (cliente, restaurante, motorizado, admin) entran por el
 * mismo endpoint: comparten el login y lo que cambia son sus permisos.
 */
class AuthController extends Controller
{
    /**
     * POST /api/login
     *
     * Devuelve un token Bearer de Sanctum para usar en las siguientes
     * peticiones:  Authorization: Bearer <token>
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::query()
            ->where('email', $request->validated('email'))
            ->first();

        // Mismo mensaje si el correo no existe o si la contrasena esta mal.
        // Si diferenciaramos, cualquiera podria descubrir que correos estan
        // registrados en ToroGo probando uno por uno (enumeracion de usuarios).
        if (! $user || ! Hash::check($request->validated('password'), $user->password)) {
            throw ValidationException::withMessages([
                'email' => 'Las credenciales no coinciden.',
            ]);
        }

        // Sanctum aplica solo la expiracion de config/sanctum.php (7 dias).
        $token = $user->createToken(
            $request->validated('device_name') ?? 'app-movil'
        );

        return response()->json([
            'token' => $token->plainTextToken,
            'token_type' => 'Bearer',
            'expires_in_minutes' => (int) config('sanctum.expiration'),
            'user' => new UserResource($user),
        ]);
    }

    /**
     * GET /api/me
     *
     * Devuelve el usuario dueno del token enviado. La app lo usa al abrir
     * para saber si la sesion sigue viva, sin pedir la clave otra vez.
     */
    public function me(Request $request): UserResource
    {
        return new UserResource($request->user());
    }
}
