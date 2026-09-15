<?php

namespace App\Enums;

/**
 * Los 4 perfiles de ToroGo.
 *
 * Regla de negocio (AGENDS): solo el Cliente se registra solo desde la app.
 * Restaurante, Motorizado y Admin los da de alta el administrador.
 */
enum UserRole: string
{
    case Client = 'client';
    case Restaurant = 'restaurant';
    case Courier = 'courier';
    case Admin = 'admin';

    /**
     * Etiqueta en espanol para mostrar en la interfaz.
     * El valor guardado en la base de datos siempre es el string en ingles.
     */
    public function label(): string
    {
        return match ($this) {
            self::Client => 'Cliente',
            self::Restaurant => 'Restaurante',
            self::Courier => 'Motorizado',
            self::Admin => 'Administrador',
        };
    }

    /**
     * ¿Este perfil puede crear su propia cuenta desde la app?
     * Hoy solo el Cliente. Los demas los crea el administrador.
     */
    public function canSelfRegister(): bool
    {
        return $this === self::Client;
    }

    /**
     * Todos los valores posibles. Util para validaciones y reglas.
     *
     * @return array<int, string>
     */
    public static function values(): array
    {
        return array_column(self::cases(), 'value');
    }
}
