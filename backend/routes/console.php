<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schedule;
use App\Models\Order;
use App\Enums\OrderStatus;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('orders:expire-pending', function () {
    $expired = 0;
    Order::query()->where('status', OrderStatus::Pending->value)
        ->whereNotNull('acceptance_expires_at')
        ->where('acceptance_expires_at', '<=', now())
        ->select('id')->chunkById(100, function ($orders) use (&$expired) {
            foreach ($orders as $order) {
                $expired += DB::transaction(function () use ($order) {
                    $locked = Order::query()->lockForUpdate()->find($order->id);

                    return $locked !== null && $locked->expirePending() ? 1 : 0;
                });
            }
        });
    $this->info("Pedidos vencidos: {$expired}");
})->purpose('Cancelar pedidos nuevos sin respuesta del restaurante');

Schedule::command('orders:expire-pending')->everyTenSeconds()->withoutOverlapping();
