<?php

namespace App\Events;

use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/** Un aviso compartido, sin datos del cliente ni del pedido. */
class CouriersUpdated implements ShouldBroadcastNow
{
    use Dispatchable;

    public function __construct(public readonly int $orderId) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('couriers')];
    }

    public function broadcastAs(): string
    {
        return 'order.updated';
    }

    public function broadcastWith(): array
    {
        return ['order_id' => $this->orderId];
    }
}
