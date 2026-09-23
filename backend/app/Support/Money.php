<?php

namespace App\Support;

/**
 * Las cuentas de dinero, en un solo lugar.
 *
 * Regla de todo el proyecto: el dinero NUNCA pasa por float. Un float de PHP
 * no puede representar 0.10 exacto, asi que 1.10 + 2.20 da 3.3000000000000003
 * y ese centavo fantasma aparece en la cuenta de alguien.
 *
 * Por eso los montos viajan como TEXTO ("1.50") desde la base hasta Flutter,
 * y las sumas se hacen con bcmath, que trabaja en decimal exacto.
 *
 * Esta clase existe para que la regla se aplique igual en todos lados: si
 * cada controlador sumara a su manera, alcanzaria con que uno solo use '+' para
 * que los numeros dejen de cuadrar.
 */
class Money
{
    /**
     * Cuantos decimales tiene la moneda. Todo el proyecto usa 2.
     */
    private const SCALE = 2;

    /**
     * Suma dos o mas montos.
     */
    public static function add(string ...$amounts): string
    {
        $total = '0.00';

        foreach ($amounts as $amount) {
            $total = bcadd($total, $amount, self::SCALE);
        }

        return $total;
    }

    /**
     * Multiplica un monto por una cantidad entera (precio x cantidad).
     */
    public static function multiply(string $amount, int $quantity): string
    {
        return bcmul($amount, (string) $quantity, self::SCALE);
    }

    /**
     * Resta dos montos.
     */
    public static function subtract(string $amount, string $other): string
    {
        return bcsub($amount, $other, self::SCALE);
    }

    /**
     * ¿El monto es mayor que cero?
     */
    public static function isPositive(string $amount): bool
    {
        return bccomp($amount, '0', self::SCALE) === 1;
    }
}
