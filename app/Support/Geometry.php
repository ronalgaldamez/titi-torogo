<?php

namespace App\Support;

/**
 * Geometria basica para las zonas de reparto.
 *
 * Se calcula en PHP y no en la base de datos a proposito: con una zona de
 * 82 vertices el recorrido es instantaneo, y evita instalar PostGIS.
 *
 * Si algun dia hay cientos de zonas, el camino es PostGIS
 * (ST_Contains para "esta dentro" y ST_DWithin para la tolerancia).
 */
class Geometry
{
    /**
     * ¿El punto cae dentro del poligono?
     *
     * Usa el algoritmo del "rayo" (ray casting): se lanza una linea
     * horizontal desde el punto hacia la derecha y se cuentan cuantas veces
     * cruza el contorno. Si son impares, el punto esta adentro.
     *
     * @param  array<int, array{0: float|int, 1: float|int}>  $ring
     *         Anillo de pares [longitud, latitud], en orden GeoJSON.
     */
    public static function pointInPolygon(float $latitude, float $longitude, array $ring): bool
    {
        $inside = false;
        $count = count($ring);

        for ($i = 0, $j = $count - 1; $i < $count; $j = $i++) {
            $lonI = (float) $ring[$i][0];
            $latI = (float) $ring[$i][1];
            $lonJ = (float) $ring[$j][0];
            $latJ = (float) $ring[$j][1];

            // El lado solo cuenta si cruza la latitud del punto...
            if ((($latI > $latitude) !== ($latJ > $latitude))
                // ...y si el cruce ocurre a la derecha del punto.
                && ($longitude < ($lonJ - $lonI) * ($latitude - $latI) / ($latJ - $latI) + $lonI)) {
                $inside = ! $inside;
            }
        }

        return $inside;
    }
}
