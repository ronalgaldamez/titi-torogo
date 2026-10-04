<?php

namespace App\Enums;

/**
 * El vehiculo con el que reparte un motorizado.
 *
 * Va como enum y no como texto suelto por lo mismo que UserRole: si cada
 * pantalla escribiera el vehiculo a mano, un dia aparece "Moto", otro "moto" y
 * otro "Motocicleta", y despues no hay forma de contar cuantos hay de cada uno.
 *
 * Es un enum de PHP, no de base de datos: se guarda el texto para poder sumar
 * un vehiculo nuevo sin una migracion.
 */
enum Vehicle: string
{
    case Motorcycle = 'moto';
    case Car = 'carro';
    case Bicycle = 'bicicleta';

    /**
     * El nombre que se muestra en el panel y en la app.
     */
    public function label(): string
    {
        return match ($this) {
            self::Motorcycle => 'Moto',
            self::Car => 'Carro',
            self::Bicycle => 'Bicicleta',
        };
    }

    /**
     * Todos los valores, para las reglas de validacion.
     *
     * @return array<int, string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
