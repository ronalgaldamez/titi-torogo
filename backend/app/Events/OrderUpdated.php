<?php

namespace App\Events;

use App\Http\Resources\OrderResource;
use App\Models\Order;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Http\Request;
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
 * POR QUE UN EVENTO Y NO TRES
 *
 * Porque para el telefono los tres significan lo mismo: "aca esta el pedido
 * otra vez, pintalo". Tres eventos distintos obligarian a la app a tener tres
 * manejadores que hacen lo mismo.
 *
 * POR QUE ShouldBroadcastNow Y NO ShouldBroadcast
 *
 * ShouldBroadcast ENCOLA el aviso. Hoy NO hay ningun worker de colas corriendo
 * (el docker-compose no levanta ninguno), asi que ese aviso se quedaria en la
 * cola de Redis para siempre y pareceria que Reverb esta roto. Con Now, el
 * aviso sale en el momento. El dia que montemos el worker, se cambia esta
 * interfaz por ShouldBroadcast y listo.
 *
 * POR QUE EL PAYLOAD ES EL MISMO OrderResource DE LA API
 *
 * Para que el telefono no tenga que aprender dos formatos. Lo que llega por
 * WebSocket se lee con el MISMO Order.fromJson que lo que llega por HTTP, asi
 * que no puede pasar que un dia digan cosas distintas.
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

    /**
     * Avisa a los tres, cargando lo que el resource necesita.
     *
     * Existe para que los cuatro lugares que avisan (crear, aceptar/mover,
     * tomar, recogido/entregado) NO tengan que acordarse de cargar los platos,
     * el restaurante y el motorizado. Si un dia se agrega un quinto lugar, con
     * llamar a esto ya sale completo.
     */
    public static function announce(Order $order, ?string $previousStatus = null): void
    {
        self::dispatch($order->load(['items', 'restaurant', 'courier']), $previousStatus);
    }

    /**
     * El canal del pedido. Es PRIVADO: sin permiso no se escucha.
     *
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [new PrivateChannel('orders.'.$this->order->id)];
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
        return [
            // El pedido COMPLETO, con la misma forma que devuelve
            // PATCH /api/orders/{id}. El telefono lo reemplaza entero y no
            // tiene que ir a buscar nada.
            //
            // resolve() y no toArray(): resolve() es el MISMO camino que usa un
            // controlador cuando devuelve el resource (resuelve los platos y
            // saca los campos que no van). Con toArray() a mano, los platos
            // viajarian como objetos y no como lista, y el telefono no los
            // podria leer.
            'order' => OrderResource::make($this->order)->resolve(new Request),

            // Para que la app sepa si esto es "cambio de estado" (y suene el
            // aviso) o solo "le asignaron motorizado" (que no suene).
            'previous_status' => $this->previousStatus,
        ];
    }
}
