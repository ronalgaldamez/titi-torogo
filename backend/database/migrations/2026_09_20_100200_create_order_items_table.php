<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Los platos de un pedido.
     *
     * Cada linea guarda una COPIA del plato, no solo su id.
     *
     * Es la diferencia entre un historial que sirve y uno que miente: si el
     * restaurante le sube el precio a la pupusa la semana que viene, el
     * pedido de hoy tiene que seguir diciendo lo que se pago hoy. Guardando
     * solo el product_id, el historial se reescribiria solo y las cuentas de
     * un mes pasado dejarian de cuadrar.
     */
    public function up(): void
    {
        Schema::create('order_items', function (Blueprint $table) {
            $table->id();

            $table->foreignId('order_id')->constrained()->cascadeOnDelete();

            // Referencia al plato para estadisticas ("el mas vendido", que la
            // biblia pide en el panel del restaurante). Puede quedar en null
            // si el restaurante lo borra: el historial NO depende de que el
            // plato siga existiendo.
            $table->foreignId('product_id')->nullable()->constrained()->nullOnDelete();

            // La copia: como se llamaba y cuanto costaba cuando se pidio.
            $table->string('name');
            $table->decimal('unit_price', 8, 2);

            $table->unsignedSmallInteger('quantity');

            // Guardado y no calculado al vuelo: es una linea de la cuenta.
            // Si algun dia cambia la forma de redondear, los pedidos viejos
            // no se mueven.
            $table->decimal('subtotal', 8, 2);

            $table->timestamps();

            $table->index('order_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('order_items');
    }
};
