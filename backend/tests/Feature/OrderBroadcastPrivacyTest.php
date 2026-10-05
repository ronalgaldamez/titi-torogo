<?php

namespace Tests\Feature;

use App\Enums\OrderStatus;
use App\Events\CouriersUpdated;
use App\Events\OrderUpdated;
use App\Http\Resources\AvailableOrderResource;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Models\Restaurant;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Event;
use Mockery;
use Tests\TestCase;

class OrderBroadcastPrivacyTest extends TestCase
{
    public function test_available_list_hides_delivery_but_assigned_order_keeps_it(): void
    {
        $order = new Order;
        $order->id = 42;
        $order->status = OrderStatus::Ready;
        $order->delivery_address = 'Dirección privada del cliente';
        $order->delivery_reference = 'Referencia privada';
        $order->delivery_latitude = 14.1;
        $order->delivery_longitude = -89.1;
        $order->notes = 'Nota privada';
        $order->total = '12.00';
        $restaurant = new Restaurant;
        $restaurant->id = 7;
        $restaurant->name = 'Restaurante';
        $order->setRelation('restaurant', $restaurant);
        $order->setRelation('items', collect());

        $available = (new AvailableOrderResource($order))->resolve(new Request);
        $assigned = (new OrderResource($order))->resolve(new Request);

        $this->assertArrayNotHasKey('delivery', $available);
        $this->assertArrayNotHasKey('notes', $available);
        $this->assertSame('12.00', $available['total']);
        $this->assertSame('Dirección privada del cliente', $assigned['delivery']['address']);
        $this->assertSame('Referencia privada', $assigned['delivery']['reference']);
        $this->assertSame(14.1, $assigned['delivery']['latitude']);
        $this->assertSame('Nota privada', $assigned['notes']);
    }

    public function test_shared_channel_receives_only_the_order_id(): void
    {
        $event = new CouriersUpdated(42);

        $this->assertSame(['private-couriers'], array_map(
            fn ($channel) => $channel->name, $event->broadcastOn(),
        ));
        $this->assertSame(['order_id' => 42], $event->broadcastWith());
        $this->assertSame('order.updated', $event->broadcastAs());
    }

    public function test_full_order_is_never_sent_to_the_shared_channel(): void
    {
        $order = new Order;
        $order->id = 42;
        $order->restaurant_id = 7;
        $order->status = OrderStatus::Ready;

        $event = new OrderUpdated($order);

        $this->assertSame(['private-orders.42', 'private-restaurants.7'], array_map(
            fn ($channel) => $channel->name, $event->broadcastOn(),
        ));
    }

    public function test_shared_notice_is_sent_when_entering_or_leaving_ready(): void
    {
        foreach ([
            [OrderStatus::Ready, 'preparing', true],
            [OrderStatus::Ready, 'ready', true],
            [OrderStatus::PickedUp, 'ready', true],
            [OrderStatus::Cancelled, 'ready', true],
            [OrderStatus::Accepted, 'pending', false],
        ] as [$status, $previous, $expected]) {
            Event::fake([OrderUpdated::class, CouriersUpdated::class]);
            $order = Mockery::mock(Order::class)->makePartial();
            $order->id = 42;
            $order->status = $status;
            $order->shouldReceive('load')->once()
                ->with(['items', 'restaurant', 'courier'])->andReturnSelf();

            OrderUpdated::announce($order, $previous);

            Event::assertDispatched(OrderUpdated::class);
            if ($expected) {
                Event::assertDispatched(CouriersUpdated::class,
                    fn ($event) => $event->orderId === 42);
            } else {
                Event::assertNotDispatched(CouriersUpdated::class);
            }
        }
    }
}
