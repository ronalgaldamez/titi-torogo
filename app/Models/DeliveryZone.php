<?php

namespace App\Models;

use App\Support\Geometry;
use Illuminate\Database\Eloquent\Model;

/**
 * Una zona donde ToroGo entrega.
 *
 * El poligono viene dibujado en Google My Maps y se importa con
 * DeliveryZoneSeeder. No se dibuja dos veces.
 *
 * Las tarifas viven aqui y no en el restaurante: el motorizado es de la
 * plataforma, asi que la plataforma define el precio del envio. Cada zona
 * puede tener su precio, y una zona mas lejana cobra mas.
 */
class DeliveryZone extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'polygon',
        'courier_fee',
        'platform_fee',
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
            'courier_fee' => 'decimal:2',
            'platform_fee' => 'decimal:2',
            'is_active' => 'boolean',
        ];
    }

    /**
     * ¿Esta zona cubre el punto dado?
     *
     * Es la pregunta que responde el Home: el cliente manda su ubicacion,
     * averiguamos en que zona cae, y mostramos los restaurantes disponibles.
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

    /**
     * Lo que paga el cliente por el envio: las dos lineas juntas.
     *
     * Se calcula y no se guarda, para que el recibo nunca pueda mostrar
     * un total que no coincida con sus partes.
     *
     * Se usa bcadd (y no una suma normal) porque los montos llegan como
     * texto desde el cast decimal, y bcadd suma decimales exactos: con
     * floats, $1.10 + $2.20 puede dar 3.3000000000000003.
     */
    public function deliveryFee(): string
    {
        return bcadd($this->courier_fee, $this->platform_fee, 2);
    }
}
