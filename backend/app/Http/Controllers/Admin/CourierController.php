<?php

namespace App\Http\Controllers\Admin;

use App\Enums\UserRole;
use App\Enums\Vehicle;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StoreCourierRequest;
use App\Http\Requests\Admin\UpdateCourierRequest;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * La gestion de motorizados del panel: la biblia la pide como "Lista de
 * motorizados (crear, editar, activar/desactivar)".
 *
 * ES MAS SIMPLE QUE RESTAURANTES, y no por descuido: el motorizado no tiene
 * ficha aparte. Es una cuenta (users) con role = courier, su telefono y su
 * vehiculo. Por eso aca no hay transaccion ni dos filas que crear.
 *
 * NO HAY BORRAR: un motorizado tiene pedidos entregados e historial, y borrarlo
 * dejaria esos pedidos sin responsable. Para sacarlo de circulacion esta
 * DESACTIVAR, que ademas le corta el acceso a la app (ver EnsureCourierAccount).
 *
 * OJO CON UNA COSA QUE NO SE TOCA ACA: 'is_available'. Ese es el "hoy salgo a
 * repartir" del propio motorizado, no una decision del administrador. El panel
 * lo muestra, pero no lo cambia: seria raro que la oficina ponga a alguien a
 * trabajar sin preguntarle.
 */
class CourierController extends Controller
{
    /**
     * GET /admin/motorizados
     */
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('buscar'));

        $couriers = User::query()
            ->where('role', UserRole::Courier->value)
            // ilike: "juan" tiene que encontrar a "Juan".
            ->when(
                $search !== '',
                fn ($query) => $query->where(function ($query) use ($search): void {
                    $query->where('name', 'ilike', "%{$search}%")
                        ->orWhere('email', 'ilike', "%{$search}%");
                }),
            )
            ->orderBy('name')
            ->get();

        return view('admin.couriers.index', [
            'couriers' => $couriers,
            'search' => $search,
        ]);
    }

    /**
     * GET /admin/motorizados/crear
     */
    public function create(): View
    {
        return view('admin.couriers.create');
    }

    /**
     * POST /admin/motorizados
     */
    public function store(StoreCourierRequest $request): RedirectResponse
    {
        $user = new User;

        $user->name = $request->validated('name');
        $user->email = $request->validated('email');
        $user->password = $request->validated('password'); // el cast 'hashed' lo encripta
        $user->phone = $request->validated('phone');
        $user->vehicle = $request->validated('vehicle');

        // El perfil se fuerza ACA: 'role' no es fillable, asi que ningun campo
        // del formulario puede convertirlo en administrador.
        $user->role = UserRole::Courier;
        $user->email_verified_at = now();

        // Nace activo, y NO disponible: la disponibilidad la prende el
        // motorizado desde su app cuando sale a trabajar (ver la migracion de
        // is_available). Si naciera disponible, empezaria a recibir pedidos sin
        // haber aceptado.
        $user->is_active = true;
        $user->is_available = false;

        $user->save();

        return redirect()
            ->route('admin.couriers.index')
            ->with('status', "«{$user->name}» quedó creado. Entra con {$user->email}.");
    }

    /**
     * GET /admin/motorizados/{courier}/editar
     */
    public function edit(User $courier): View
    {
        $this->ensureIsCourier($courier);

        return view('admin.couriers.edit', ['courier' => $courier]);
    }

    /**
     * PUT /admin/motorizados/{courier}
     */
    public function update(UpdateCourierRequest $request, User $courier): RedirectResponse
    {
        $this->ensureIsCourier($courier);

        $courier->name = $request->validated('name');
        $courier->email = $request->validated('email');
        $courier->phone = $request->validated('phone');
        $courier->vehicle = $request->validated('vehicle');

        // La contraseña SOLO se toca si escribieron una nueva.
        if ($request->filled('password')) {
            $courier->password = $request->validated('password');
        }

        $courier->save();

        return redirect()
            ->route('admin.couriers.index')
            ->with('status', "«{$courier->name}» quedó actualizado.");
    }

    /**
     * POST /admin/motorizados/{courier}/activar
     */
    public function toggle(User $courier): RedirectResponse
    {
        $this->ensureIsCourier($courier);

        $courier->is_active = ! $courier->is_active;

        // Al dar de baja tambien se lo saca de disponible: si quedara
        // "disponible" con la cuenta desactivada, el estado que se ve en el
        // panel seria mentira.
        if (! $courier->is_active) {
            $courier->is_available = false;
        }

        $courier->save();

        $status = $courier->is_active
            ? "«{$courier->name}» quedó activo: puede volver a entrar a la app."
            : "«{$courier->name}» quedó desactivado: no puede entrar a la app ni recibir pedidos.";

        return redirect()
            ->route('admin.couriers.index')
            ->with('status', $status);
    }

    /**
     * Un id que no sea de motorizado da 404.
     *
     * Hace falta porque {courier} ata CUALQUIER usuario por id: sin esto,
     * entrar a /admin/motorizados/1/editar abriria la cuenta del administrador
     * (que es la 1), y guardar le pisaria el nombre, el correo y el telefono.
     *
     * Se responde 404 y no 403 a proposito: para el panel, esa direccion
     * simplemente no existe.
     */
    private function ensureIsCourier(User $courier): void
    {
        abort_unless($courier->hasRole(UserRole::Courier), 404);
    }
}
