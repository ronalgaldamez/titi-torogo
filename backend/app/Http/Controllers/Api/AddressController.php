<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AddressRequest;
use App\Http\Resources\AddressResource;
use App\Models\Address;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Las direcciones guardadas del cliente.
 *
 * La biblia las pide como pantalla propia ("Mis direcciones") y como paso del
 * checkout ("Confirmar direccion: elegir entre guardadas").
 *
 * Todo pasa por $request->user()->addresses(), asi que las consultas salen de
 * la relacion: la direccion de otro usuario responde 404 y no existe para
 * nosotros.
 */
class AddressController extends Controller
{
    /**
     * GET /api/addresses
     *
     * La predeterminada primero: es la que el checkout viene eligiendo.
     */
    public function index(Request $request): JsonResponse
    {
        $addresses = $request->user()->addresses()
            ->orderByDesc('is_default')
            ->latest()
            ->get();

        return response()->json([
            'addresses' => AddressResource::collection($addresses),
        ]);
    }

    /**
     * POST /api/addresses
     */
    public function store(AddressRequest $request): JsonResponse
    {
        $user = $request->user();

        $address = DB::transaction(function () use ($user, $request): Address {
            $address = new Address;

            // Campo por campo. 'user_id' NO es fillable: sale de la sesion.
            $address->user_id = $user->id;
            $address->label = $request->validated('label');
            $address->address = $request->validated('address');
            $address->reference = $request->validated('reference');
            $address->latitude = $request->validated('latitude');
            $address->longitude = $request->validated('longitude');

            // La PRIMERA direccion es la predeterminada aunque no lo pidan.
            // Sin ninguna marcada, el checkout no tendria que elegir sola y el
            // cliente veria un paso de mas.
            $isFirst = $user->addresses()->count() === 0;
            $address->is_default = $isFirst;

            $address->save();

            if ($isFirst || $request->validated('is_default') === true) {
                $this->makeDefault($user, $address);
            }

            return $address;
        });

        return response()->json([
            'address' => new AddressResource($address),
        ], 201);
    }

    /**
     * PUT /api/addresses/{address}
     *
     * El formulario manda la direccion completa, por eso PUT y no PATCH.
     */
    public function update(AddressRequest $request, int $address): JsonResponse
    {
        $user = $request->user();

        // Sobre la relacion: la direccion de otro responde 404.
        $model = $user->addresses()->findOrFail($address);

        DB::transaction(function () use ($user, $model, $request): void {
            $model->label = $request->validated('label');
            $model->address = $request->validated('address');
            $model->reference = $request->validated('reference');
            $model->latitude = $request->validated('latitude');
            $model->longitude = $request->validated('longitude');
            $model->save();

            // Si pidieron marcarla, se marca. Si no pidieron nada, se deja
            // como estaba: desmarcarla desde el formulario dejaria al cliente
            // sin predeterminada y sin manera de elegir otra.
            if ($request->validated('is_default') === true) {
                $this->makeDefault($user, $model);
            }
        });

        return response()->json([
            'address' => new AddressResource($model),
        ]);
    }

    /**
     * DELETE /api/addresses/{address}
     *
     * Borrado SUAVE. Los pedidos viejos no se enteran: guardan su propia
     * copia de la direccion (ver la migracion de orders).
     */
    public function destroy(Request $request, int $address): JsonResponse
    {
        $user = $request->user();

        $model = $user->addresses()->findOrFail($address);

        DB::transaction(function () use ($user, $model): void {
            $wasDefault = $model->is_default;

            $model->delete();

            // Si se borro la predeterminada, se promueve la mas reciente que
            // quede. Dejar al cliente sin ninguna marcada lo obligaria a
            // elegir a mano en cada pedido.
            if ($wasDefault) {
                $next = $user->addresses()->latest()->first();

                if ($next !== null) {
                    $this->makeDefault($user, $next);
                }
            }
        });

        return response()->json([
            'message' => 'Dirección eliminada.',
        ]);
    }

    /**
     * Deja UNA sola direccion predeterminada.
     *
     * El orden importa: primero se apagan TODAS y despues se prende la
     * elegida. Al reves quedaria un instante con dos predeterminadas, y si
     * algo fallara en el medio, quedarian las dos para siempre.
     */
    private function makeDefault(User $user, Address $address): void
    {
        $user->addresses()
            ->whereKeyNot($address->id)
            ->update(['is_default' => false]);

        $address->is_default = true;
        $address->save();
    }
}
