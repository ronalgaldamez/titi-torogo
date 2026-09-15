<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Reemplaza la tarifa unica de la zona por las DOS lineas que ve el cliente.
     *
     *   courier_fee  -> va completa al motorizado
     *   platform_fee -> es el ingreso de ToroGo
     *
     * El total que paga el cliente NO se guarda: se calcula sumando las dos
     * (ver DeliveryZone::deliveryFee()). Asi es imposible que queden
     * desincronizadas y que el recibo muestre un numero que no cuadra.
     */
    public function up(): void
    {
        Schema::table('delivery_zones', function (Blueprint $table) {
            $table->dropColumn('delivery_fee');

            $table->decimal('courier_fee', 8, 2)->default(0);
            $table->decimal('platform_fee', 8, 2)->default(0);
        });
    }

    public function down(): void
    {
        Schema::table('delivery_zones', function (Blueprint $table) {
            $table->dropColumn(['courier_fee', 'platform_fee']);
            $table->decimal('delivery_fee', 8, 2)->default(0);
        });
    }
};
