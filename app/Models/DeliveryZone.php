<?php

namespace App\Models;

use App\Support\Geometry;
use Illuminate\Database\Eloquent\Model;

/**
 * Una zona donde ToroGo entrega.
 *
 * El poligono viene dibujado en Google My Maps y se importa con
 * DeliveryZoneSeeder. No se dibuja dos veces.
 */
class DeliveryZone extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'polygon',
        'delivery_fee',
    ];

    /*
     * 'is_active' NO es fillable: solo el administrador activa o desactiva
     * una zona, igual que con los restaurantes.
     */

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'polygon' => 'array',
            'delivery_fee' => 'decimal:2',
            'is_active' => 'boolean',
        ];
    }

    /**
     * ¿Esta zona cubre el punto dado?
     *
     * Es la pregunta que responde el Home: el cliente manda su ubicacion,
     * averiguamos en que zona cae, y mostramos los restaurantes de esa zona.
     */
    public function contains(float $latitude, float $longitude): bool
    {
        // Un poligono GeoJSON puede tener varios anillos: el primero es el
        // contorno exterior y los siguientes serian huecos. Por ahora solo
        // usamos el exterior.
        $ring = $this->polygon['coordinates'][0] ?? [];

        if ($ring === []) {
            return false;
        }

        return Geometry::pointInPolygon($latitude, $longitude, $ring);
    }
}
