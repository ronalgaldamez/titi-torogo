<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
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
 * mismo login: comparten credenciales y token; lo que cambia son permisos.
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

        return $this->tokenResponse($user, $request->validated('device_name'));
    }

    /**
     * POST /api/register
     *
     * Registro de CLIENTES. Devuelve el token de una vez para que la app
     * no tenga que pedir el login despues (el AGENDS pide "Login/Registro
     * combinado").
     *
     * Restaurante, Motorizado y Admin NO pasan por aqui: los crea el
     * administrador desde el panel.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = new User;

        // Asignamos campo por campo, nunca User::create($request->all()).
        // Asi es imposible que un campo que no esperamos se cuele.
        $user->name = $request->validated('name');
        $user->email = $request->validated('email');
        $user->password = $request->validated('password'); // el cast 'hashed' lo encripta

        // EL PUNTO CRITICO DE SEGURIDAD:
        // El perfil se fuerza aqui, en el servidor. Alguien puede mandar
        // {"role":"admin"} en el body y da igual: 'role' no esta en las
        // reglas de RegisterRequest ni en $fillable del modelo. Doble barrera.
        $user->role = UserRole::Client;

        $user->save();

        return $this->tokenResponse($user, $request->validated('device_name'), 201);
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

    /**
     * POST /api/logout
     *
     * Revoca SOLO el token con el que se hizo esta peticion: el usuario cierra
     * sesion en este telefono sin desconectar sus otros dispositivos.
     *
     * Para cerrar sesion en TODOS los dispositivos a la vez (por ejemplo,
     * cuando se da de baja a un motorizado) se usa:
     *     $user->tokens()->delete();
     * Eso es lo que va a hacer el panel de administracion mas adelante.
     */
    public function logout(Request $request): JsonResponse
    {
        // El "?->" cubre el caso de una sesion por cookie en vez de token:
        // ahi currentAccessToken() devuelve null y no hay token que borrar.
        $request->user()->currentAccessToken()?->delete();

        return response()->json([
            'message' => 'Sesion cerrada.',
        ]);
    }

    /**
     * Emite el token y arma la respuesta que consumen las apps Flutter.
     *
     * Lo comparten login y register para que ambos devuelvan EXACTAMENTE
     * la misma forma de respuesta.
     *
     * La expiracion (7 dias) la aplica Sanctum desde config/sanctum.php.
     */
    private function tokenResponse(User $user, ?string $deviceName, int $status = 200): JsonResponse
    {
        $token = $user->createToken($deviceName ?? 'app-movil');

        return response()->json([
            'token' => $token->plainTextToken,
            'token_type' => 'Bearer',
            'expires_in_minutes' => (int) config('sanctum.expiration'),
            'user' => new UserResource($user),
        ], $status);
    }
}
