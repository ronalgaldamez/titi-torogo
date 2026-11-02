<?php

namespace App\Events;

use App\Enums\OrderStatus;
use App\Models\Order;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * "Este pedido cambio."
 *
 * Es un solo evento para los tres momentos en que un pedido cambia y alguien
 * tiene que enterarse:
 *
 *   - lo acaba de crear el cliente      -> el restaurante lo ve llegar
 *   - el restaurante lo mueve de estado -> el cliente ve "en preparacion"
 *   - el motorizado lo toma o lo mueve  -> el cliente ve quien lo lleva
 *
 * Los tres lo escuchan por el canal privado del pedido, y quien puede entrar a
 * ese canal lo decide routes/channels.php, NO este archivo.
 *
 * El canal compartido de motorizados recibe CouriersUpdated: solo el id.
 * El pedido completo nunca se publica en ese canal.
 *
 * POR QUE ShouldBroadcastNow Y NO ShouldBroadcast
 *
 * ShouldBroadcast ENCOLA el aviso. Hoy NO hay ningun worker de colas corriendo
 * (el docker-compose no levanta ninguno), asi que ese aviso se quedaria en la
 * cola de Redis para siempre y pareceria que Reverb esta roto. Con Now, el
 * aviso sale en el momento. El dia que montemos el worker, se cambia esta
 * interfaz por ShouldBroadcast y listo.
 *
 * Los avisos solo identifican el pedido; la API valida el acceso actual al detalle.
 */
class OrderUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * @param  string|null  $previousStatus  El estado de ANTES. Null = el
     *                                       pedido es nuevo y no habia antes.
     */
    public function __construct(
        public readonly Order $order,
        public readonly ?string $previousStatus = null,
    ) {}

    public static function announce(Order $order, ?string $previousStatus = null): void
    {
        self::dispatch($order, $previousStatus);

        if ($order->status === OrderStatus::Ready
            || $previousStatus === OrderStatus::Ready->value
            || $order->wasChanged('courier_id')) {
            CouriersUpdated::dispatch($order->id);
        }
    }

    /**
     * Los canales por los que sale este aviso.
     *
     * Son DOS, y cada uno tiene su publico:
     *
     *   1. El canal del pedido: el cliente que lo pidio y el motorizado que lo
     *      lleva.
     *   2. El canal del restaurante: para que vea entrar y moverse TODO lo de
     *      su cocina por un solo lugar. Lo necesita aparte porque NO puede
     *      suscribirse al canal de un pedido cuyo numero todavia no conoce, y
     *      el que acaba de entrar es justamente ese.
     * Ambos son PRIVADOS: quien entra lo decide routes/channels.php.
     *
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('orders.'.$this->order->id),
            new PrivateChannel('restaurants.'.$this->order->restaurant_id),
        ];

    }

    /**
     * El nombre con el que viaja por el cable.
     *
     * Sin esto el evento se llama como la clase completa
     * (App\Events\OrderUpdated), y ahi mover el archivo de carpeta rompe a
     * todos los telefonos. Con un nombre corto y fijo, el archivo se puede
     * renombrar sin tocar la app.
     */
    public function broadcastAs(): string
    {
        return 'order.updated';
    }

    /**
     * Lo que le llega al telefono.
     *
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        // Una suscripción antigua no debe recibir datos privados tras una reasignación.
        return ['order_id' => $this->order->id, 'previous_status' => $this->previousStatus];
    }
}
