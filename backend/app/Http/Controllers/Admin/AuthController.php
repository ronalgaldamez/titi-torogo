<?php

namespace App\Http\Controllers\Admin;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

/**
 * El login del panel de administracion.
 *
 * Es un login de SESION (cookie), distinto del de la app movil, que usa un
 * token Bearer de Sanctum. Los dos leen la MISMA tabla de usuarios: lo que
 * cambia es como se mantiene la sesion, y que este panel solo deja pasar al
 * administrador.
 */
class AuthController extends Controller
{
    public function showLogin(): View
    {
        return view('admin.login');
    }

    public function login(Request $request): RedirectResponse
    {
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        if (! Auth::attempt($credentials, $request->boolean('remember'))) {
            // El mismo mensaje para correo inexistente y para contrasena mala,
            // igual que en la API: si diferenciaramos, cualquiera podria
            // averiguar que correos existen probando uno por uno.
            throw ValidationException::withMessages([
                'email' => 'Las credenciales no coinciden.',
            ]);
        }

        // La sesion ya se abrio; ahora se revisa el PERFIL. Se cierra si no es
        // el administrador: dejarlo adentro para mostrarle un 403 despues seria
        // peor, porque ya tendria sesion en el panel.
        if (! $request->user()->hasRole(UserRole::Admin)) {
            Auth::logout();
            $request->session()->invalidate();
            $request->session()->regenerateToken();

            throw ValidationException::withMessages([
                'email' => 'Esta cuenta no es de administrador.',
            ]);
        }

        // Regenerar el id de sesion al entrar evita la fijacion de sesion: si
        // alguien consiguio el id antes de entrar, el viejo ya no sirve.
        $request->session()->regenerate();

        return redirect()->intended(route('admin.dashboard'));
    }

    public function logout(Request $request): RedirectResponse
    {
        Auth::logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login');
    }
}
