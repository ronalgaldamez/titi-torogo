<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * La tarifa de envio del restaurante pasa a ser OPCIONAL.
     *
     *   null   -> "usá la tarifa de mi zona"  (el caso normal, el 95%)
     *   0.00   -> "envío gratis, lo absorbo yo" (promoción del restaurante)
     *   2.50   -> "yo pongo una tarifa distinta" (raro, pero posible)
     *
     * El dinero del envio es de la plataforma porque el motorizado es de la
     * plataforma: el restaurante no controla la distancia ni el costo real.
     */
    public function up(): void
    {
        Schema::table('restaurants', function (Blueprint $table) {
            $table->decimal('delivery_fee', 8, 2)->nullable()->default(null)->change();
        });
    }

    public function down(): void
    {
        Schema::table('restaurants', function (Blueprint $table) {
            $table->decimal('delivery_fee', 8, 2)->nullable(false)->default(0)->change();
        });
    }
};
