<?php

namespace Database\Seeders;

use App\Models\DeliveryZone;
use Illuminate\Database\Seeder;
use RuntimeException;

/**
 * Importa las zonas de reparto desde el KML exportado de Google My Maps.
 *
 * Asi no hay que dibujar dos veces: se dibuja en My Maps, se exporta, y
 * este seeder lo mete en la base de datos.
 *
 * El archivo vive en database/data/ y SI se versiona en Git: las zonas de
 * reparto son un dato del negocio, y tenerlas en el repo significa que
 * cualquiera del equipo puede re-sembrarlas.
 */
class DeliveryZoneSeeder extends Seeder
{
    private const KML_PATH = 'data/zonas-de-envio.kml';

    public function run(): void
    {
        $path = database_path(self::KML_PATH);

        if (! is_file($path)) {
            throw new RuntimeException(
                "No se encontro el archivo de zonas en: {$path}\n".
                'Exportalo desde Google My Maps (menu del mapa -> Exportar a KML) '.
                'y guardalo con ese nombre.'
            );
        }

        $ring = $this->readFirstRing($path);

        // Asignacion explicita campo por campo: 'is_active' no es fillable.
        $zone = DeliveryZone::firstOrNew(['name' => 'Tejutla']);

        $zone->polygon = [
            'type' => 'Polygon',
            'coordinates' => [$ring],
        ];
        // Las DOS lineas que ve el cliente en el recibo:
        //   courier_fee  -> va completa al motorizado
        //   platform_fee -> es el ingreso de ToroGo
        // El cliente paga la suma ($2.00), calculada por DeliveryZone::deliveryFee().
        //
        // Si algun dia se dibuja una zona mas lejana, a ESA zona se le sube
        // el courier_fee y Tejutla conserva el suyo. Cada zona su precio.
        $zone->courier_fee = 1.50;
        $zone->platform_fee = 0.50;
        $zone->is_active = true;

        $zone->save();

        $this->command?->info(sprintf(
            'Zona "Tejutla" guardada con %d vertices.',
            count($ring)
        ));
    }

    /**
     * Lee el primer poligono del KML y lo devuelve como anillo GeoJSON.
     *
     * @return array<int, array{0: float, 1: float}>
     */
    private function readFirstRing(string $path): array
    {
        $xml = simplexml_load_file($path);

        if ($xml === false) {
            throw new RuntimeException("El KML no se pudo interpretar: {$path}");
        }

        $xml->registerXPathNamespace('kml', 'http://www.opengis.net/kml/2.2');
        $nodes = $xml->xpath('//kml:Polygon//kml:coordinates');

        if (empty($nodes)) {
            throw new RuntimeException('El KML no contiene ningun poligono.');
        }

        $ring = [];

        foreach (preg_split('/\s+/', trim((string) $nodes[0])) as $pair) {
            if ($pair === '') {
                continue;
            }

            // En KML cada vertice es "longitud,latitud,altitud".
            // GeoJSON usa el mismo orden (longitud primero), asi que no
            // hay que invertir nada.
            $parts = explode(',', $pair);

            $ring[] = [(float) $parts[0], (float) $parts[1]];
        }

        if (count($ring) < 3) {
            throw new RuntimeException('El poligono tiene menos de 3 vertices.');
        }

        return $ring;
    }
}
