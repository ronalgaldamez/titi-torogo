<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\DeliveryZone;
use App\Support\Money;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/**
 * La configuracion del negocio: la biblia la pide como "Configuracion:
 * Tarifas de envio, comisiones, parametros".
 *
 * QUE SE PUEDE TOCAR Y QUE NO
 *
 * Se editan las DOS tarifas de cada zona de envio:
 *
 *   courier_fee   -> lo que se le paga al motorizado por el viaje
 *   platform_fee  -> lo que se queda ToroGo
 *
 * y el cliente paga la suma de las dos. Hoy, en Tejutla: 1.50 + 0.50 = $2.00.
 *
 * El POLIGONO de la zona NO se edita desde aca: son 82 puntos que salen del
 * archivo KML (database/data/zonas-de-envio.kml) y se cargan con el seeder. Un
 * formulario de texto para 82 coordenadas es una forma segura de romper la zona
 * de cobertura sin darse cuenta. Si hay que mover el mapa, se hace con el KML y
 * el seeder, que es donde vive la verdad.
 *
 * UNA COSA QUE HAY QUE DECIR EN PANTALLA (y se dice):
 *
 * Cambiar la tarifa NO toca los pedidos ya hechos. Cada pedido guarda una COPIA
 * de lo que costo ese dia, asi que el historial y las cuentas viejas siguen
 * diciendo la verdad. Sin ese aviso, pareceria que el historial se reescribe.
 */
class SettingsController extends Controller
{
    /**
     * GET /admin/configuracion
     */
    public function index(): View
    {
        $zones = DeliveryZone::query()->orderBy('name')->get();

        return view('admin.settings.index', [
            'zones' => $zones,
            'totalToCustomer' => $zones->mapWithKeys(fn (DeliveryZone $zone): array => [
                $zone->id => Money::add($zone->courier_fee, $zone->platform_fee),
            ]),
        ]);
    }

    /**
     * POST /admin/configuracion/{zone}
     */
    public function update(Request $request, DeliveryZone $zone): RedirectResponse
    {
        $data = $request->validate(
            [
                'courier_fee' => ['required', 'numeric', 'min:0', 'max:100'],
                'platform_fee' => ['required', 'numeric', 'min:0', 'max:100'],
            ],
            [
                'courier_fee.required' => 'Poné lo que se le paga al motorizado.',
                'courier_fee.numeric' => 'La tarifa del motorizado tiene que ser un número.',
                'platform_fee.required' => 'Poné la comisión de ToroGo.',
                'platform_fee.numeric' => 'La comisión tiene que ser un número.',
            ],
        );

        $zone->courier_fee = $data['courier_fee'];
        $zone->platform_fee = $data['platform_fee'];
        $zone->save();

        $total = Money::add($zone->courier_fee, $zone->platform_fee);

        return redirect()
            ->route('admin.settings.index')
            ->with(
                'status',
                "Tarifas de «{$zone->name}» actualizadas: el cliente paga \${$total} ".
                '($'.$zone->courier_fee.' para el motorizado y $'.$zone->platform_fee.' para ToroGo). '.
                'Los pedidos ya hechos no cambian.',
            );
    }
}
