<?php

namespace App\Enums;

/**
 * El recorrido de un pedido.
 *
 *   pending -> accepted -> preparing -> ready -> picked_up -> delivered
 *
 * y dos finales por el costado: rejected (el restaurante dijo que no) y
 * cancelled (lo corto alguien, tipicamente el administrador).
 *
 * El valor guardado en la base es SIEMPRE el string en ingles; la etiqueta en
 * espanol es solo para mostrar, igual que en UserRole.
 */
enum OrderStatus: string
{
    case Pending = 'pending';
    case Accepted = 'accepted';
    case Preparing = 'preparing';
    case Ready = 'ready';
    case PickedUp = 'picked_up';
    case Delivered = 'delivered';
    case Rejected = 'rejected';
    case Cancelled = 'cancelled';

    /**
     * Etiqueta en espanol para mostrar en la app.
     */
    public function label(): string
    {
        return match ($this) {
            self::Pending => 'Pendiente',
            self::Accepted => 'Aceptado',
            self::Preparing => 'En preparación',
            self::Ready => 'Listo para recoger',
            self::PickedUp => 'En camino',
            self::Delivered => 'Entregado',
            self::Rejected => 'Rechazado',
            self::Cancelled => 'Cancelado',
        };
    }

    /**
     * ¿El pedido ya termino? Despues de esto no se mueve mas.
     */
    public function isFinal(): bool
    {
        return match ($this) {
            self::Delivered, self::Rejected, self::Cancelled => true,
            default => false,
        };
    }

    /**
     * ¿Sigue en curso? Es lo que muestra el panel del restaurante.
     */
    public function isActive(): bool
    {
        return ! $this->isFinal();
    }

    /**
     * A que estados se puede pasar desde este.
     *
     * Esta es la maquina de estados del pedido, y vive ACA y no repartida en
     * cada controlador. Si estuviera en los controladores, tarde o temprano
     * un endpoint dejaria entregar un pedido rechazado, o aceptar uno ya
     * entregado, y nadie lo notaria hasta que pasara.
     *
     * @return array<int, self>
     */
    public function next(): array
    {
        return match ($this) {
            self::Pending => [self::Accepted, self::Rejected, self::Cancelled],
            self::Accepted => [self::Preparing, self::Cancelled],
            self::Preparing => [self::Ready, self::Cancelled],
            self::Ready => [self::PickedUp, self::Cancelled],
            self::PickedUp => [self::Delivered, self::Cancelled],
            self::Delivered, self::Rejected, self::Cancelled => [],
        };
    }

    /**
     * ¿Se puede pasar de este estado a $next?
     */
    public function canMoveTo(self $next): bool
    {
        return in_array($next, $this->next(), true);
    }

    /**
     * Que columna de tiempo se marca al entrar a este estado.
     *
     * Devuelve null cuando el estado no marca ninguna hora (pending es el
     * estado con el que nace el pedido, no una etapa por la que se pasa).
     *
     * OJO: rejected y cancelled comparten 'cancelled_at'. Para el reloj
     * significan lo mismo — el pedido dejo de estar vivo en ese momento — y
     * el estado es el que dice cual de las dos cosas fue.
     */
    public function timestampColumn(): ?string
    {
        return match ($this) {
            self::Accepted => 'accepted_at',
            self::Ready => 'ready_at',
            self::PickedUp => 'picked_up_at',
            self::Delivered => 'delivered_at',
            self::Rejected, self::Cancelled => 'cancelled_at',
            default => null,
        };
    }

    /**
     * ¿Este estado lo mueve el RESTAURANTE?
     *
     * No alcanza con que la transicion sea legal: "listo para recoger" ->
     * "recogido" es legal, pero la mueve el MOTORIZADO, no el restaurante.
     * Son dos preguntas distintas y por eso son dos verificaciones.
     */
    public function isRestaurantAction(): bool
    {
        return match ($this) {
            self::Accepted,
            self::Rejected,
            self::Preparing,
            self::Ready,
            self::Cancelled => true,
            default => false,
        };
    }

    /**
     * ¿Este estado lo mueve el MOTORIZADO?
     */
    public function isCourierAction(): bool
    {
        return match ($this) {
            self::PickedUp, self::Delivered => true,
            default => false,
        };
    }

    /**
     * Los valores de los estados finales.
     *
     * Sirve para la consulta del panel: "los pedidos EN CURSO" es
     * exactamente "los que no estan en esta lista".
     *
     * @return array<int, string>
     */
    public static function finalValues(): array
    {
        return array_values(array_map(
            fn (self $status): string => $status->value,
            array_filter(self::cases(), fn (self $status): bool => $status->isFinal()),
        ));
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
