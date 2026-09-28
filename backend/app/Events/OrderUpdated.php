<?php

namespace App\Events;

use App\Enums\OrderStatus;
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
     * Los canales por los que sale este aviso.
     *
     * Son TRES, y cada uno tiene su publico:
     *
     *   1. El canal del pedido: el cliente que lo pidio y el motorizado que lo
     *      lleva.
     *   2. El canal del restaurante: para que vea entrar y moverse TODO lo de
     *      su cocina por un solo lugar. Lo necesita aparte porque NO puede
     *      suscribirse al canal de un pedido cuyo numero todavia no conoce, y
     *      el que acaba de entrar es justamente ese.
     *   3. El canal de los motorizados, pero SOLO cuando el pedido entra o sale
     *      de la lista de disponibles (ver abajo).
     *
     * Los tres son PRIVADOS: quien entra lo decide routes/channels.php.
     *
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        $channels = [
            new PrivateChannel('orders.'.$this->order->id),
            new PrivateChannel('restaurants.'.$this->order->restaurant_id),
        ];

        // A los motorizados se les avisa SOLO cuando el pedido:
        //
        //   - ENTRA a la lista de disponibles (quedo "listo para recoger"), o
        //   - SALE de ella (alguien lo tomo, o lo cancelaron).
        //
        // Las dos cosas se reconocen con el estado de ahora y el de antes: el
        // pedido esta "listo" (entra), o lo estaba y ya no (sale).
        //
        // Todo lo demas —pendiente, aceptado, en preparacion, entregado— NO les
        // importa a los que andan en la calle, y mandarlo les haria sonar el
        // telefono por nada. Un motorizado con el telefono sonando todo el dia
        // termina silenciando la app, y ahi pierde el pedido que si le servia.
        if ($this->order->status === OrderStatus::Ready
            || $this->previousStatus === OrderStatus::Ready->value) {
            $channels[] = new PrivateChannel('couriers');
        }

        return $channels;
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
