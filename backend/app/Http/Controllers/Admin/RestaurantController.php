<?php

namespace App\Http\Controllers\Admin;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\StoreRestaurantRequest;
use App\Http\Requests\Admin\UpdateRestaurantRequest;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\View\View;

/**
 * La gestion de restaurantes del panel: la biblia la pide como "Lista de
 * restaurantes (crear, editar, activar/desactivar)".
 *
 * POR QUE ESTA PANTALLA IMPORTA TANTO
 *
 * Hasta hoy, dar de alta un restaurante era escribir en la base a mano (o
 * correr el seeder y editar despues). Con esto se hace desde el navegador,
 * que es lo que permite sumar locales de verdad.
 *
 * NO HAY BORRAR, y es a proposito: un restaurante tiene pedidos, platos e
 * historial. Borrarlo dejaria esos pedidos apuntando a un local que no existe.
 * Para sacarlo de circulacion esta DESACTIVAR: desaparece del catalogo del
 * cliente y su cuenta no puede entrar a la app.
 */
class RestaurantController extends Controller
{
    /**
     * GET /admin/restaurantes
     */
    public function index(Request $request): View
    {
        $search = trim((string) $request->query('buscar'));

        $restaurants = Restaurant::query()
            ->with('user')
            // ilike es el LIKE que NO distingue mayusculas (PostgreSQL).
            // Escribir "subway" tiene que encontrar "Subway".
            ->when(
                $search !== '',
                fn ($query) => $query->where('name', 'ilike', "%{$search}%"),
            )
            ->orderBy('name')
            ->get();

        return view('admin.restaurants.index', [
            'restaurants' => $restaurants,
            'search' => $search,
        ]);
    }

    /**
     * GET /admin/restaurantes/crear
     */
    public function create(): View
    {
        return view('admin.restaurants.create');
    }

    /**
     * POST /admin/restaurantes
     */
    public function store(StoreRestaurantRequest $request): RedirectResponse
    {
        // UNA TRANSACCION, porque se crean dos filas que van juntas: la cuenta
        // y la ficha del local. Si fallara la segunda, no queremos que quede
        // una cuenta suelta sin restaurante (que es justo el caso raro que el
        // middleware EnsureRestaurantAccount tiene que atajar).
        $restaurant = DB::transaction(function () use ($request): Restaurant {
            $user = new User;

            $user->name = $request->validated('name');
            $user->email = $request->validated('email');
            $user->password = $request->validated('password'); // el cast 'hashed' lo encripta

            // El perfil se fuerza ACA: 'role' no es fillable, asi que ningun
            // campo del formulario puede convertirlo en administrador.
            $user->role = UserRole::Restaurant;
            $user->email_verified_at = now();
            $user->save();

            $restaurant = new Restaurant;

            // 'user_id', 'is_active', 'is_open' y 'is_busy' no son fillable:
            // se asignan explicito, campo por campo.
            $restaurant->user_id = $user->id;
            $restaurant->name = $request->validated('name');
            $restaurant->description = $request->validated('description');
            $restaurant->address = $request->validated('address');
            $restaurant->phone = $request->validated('phone');
            $restaurant->latitude = $request->validated('latitude');
            $restaurant->longitude = $request->validated('longitude');
            $restaurant->prep_time_minutes = $request->validated('prep_time_minutes');
            $restaurant->delivery_fee = $request->validated('delivery_fee');

            // Nace activo y ABIERTO. Si naciera cerrado, no recibiria pedidos y
            // pareceria que la app esta rota; que lo cierre cuando quiera desde
            // su propia pantalla.
            $restaurant->is_active = true;
            $restaurant->is_open = true;
            $restaurant->is_busy = false;

            $restaurant->save();

            return $restaurant;
        });

        return redirect()
            ->route('admin.restaurants.index')
            ->with('status', "«{$restaurant->name}» quedó creado. Entra con {$restaurant->user->email}.");
    }

    /**
     * GET /admin/restaurantes/{restaurant}/editar
     */
    public function edit(Restaurant $restaurant): View
    {
        return view('admin.restaurants.edit', [
            'restaurant' => $restaurant->load('user'),
        ]);
    }

    /**
     * PUT /admin/restaurantes/{restaurant}
     */
    public function update(UpdateRestaurantRequest $request, Restaurant $restaurant): RedirectResponse
    {
        DB::transaction(function () use ($request, $restaurant): void {
            $user = $restaurant->user;

            $user->name = $request->validated('name');
            $user->email = $request->validated('email');

            // La contraseña SOLO se toca si escribieron una nueva.
            if ($request->filled('password')) {
                $user->password = $request->validated('password');
            }

            $user->save();

            $restaurant->name = $request->validated('name');
            $restaurant->description = $request->validated('description');
            $restaurant->address = $request->validated('address');
            $restaurant->phone = $request->validated('phone');
            $restaurant->latitude = $request->validated('latitude');
            $restaurant->longitude = $request->validated('longitude');
            $restaurant->prep_time_minutes = $request->validated('prep_time_minutes');
            $restaurant->delivery_fee = $request->validated('delivery_fee');
            $restaurant->save();
        });

        return redirect()
            ->route('admin.restaurants.index')
            ->with('status', "«{$restaurant->name}» quedó actualizado.");
    }

    /**
     * POST /admin/restaurantes/{restaurant}/activar
     *
     * Activa o desactiva. Es UN boton que hace las dos cosas porque el estado
     * es uno solo: no tiene sentido tener dos permisos distintos para lo mismo.
     */
    public function toggle(Restaurant $restaurant): RedirectResponse
    {
        $restaurant->is_active = ! $restaurant->is_active;
        $restaurant->save();

        $status = $restaurant->is_active
            ? "«{$restaurant->name}» quedó activo: vuelve a aparecer en la app."
            : "«{$restaurant->name}» quedó desactivado: no aparece en la app y su cuenta tampoco puede entrar.";

        return redirect()
            ->route('admin.restaurants.index')
            ->with('status', $status);
    }
}
