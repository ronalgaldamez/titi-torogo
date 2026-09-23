<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Las direcciones guardadas del cliente.
     *
     * La biblia las pide como funcionalidad propia ("Mis direcciones
     * (multiples)") y como paso del checkout ("Confirmar direccion (elegir
     * entre guardadas)"): el cliente no escribe su direccion en cada pedido,
     * elige una de las que ya tiene.
     */
    public function up(): void
    {
        Schema::create('addresses', function (Blueprint $table) {
            $table->id();

            $table->foreignId('user_id')->constrained()->cascadeOnDelete();

            // Etiqueta para reconocerla de un vistazo: "Casa", "Trabajo".
            $table->string('label');

            $table->string('address');

            // "Frente a la farmacia", "casa de dos pisos". En Tejutla esto no
            // es un adorno: es lo que hace que el motorizado llegue.
            $table->string('reference')->nullable();

            // decimal(10,7) y no float, igual que en restaurants: aqui los
            // grados se guardan con precision. La columna es decimal y el
            // modelo la castea a float para el mapa.
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);

            // La que viene elegida en el checkout.
            $table->boolean('is_default')->default(false);

            $table->timestamps();

            // La biblia pide soft deletes: si el cliente borra una direccion,
            // los pedidos viejos que la usaron no deben quedar huerfanos.
            $table->softDeletes();

            $table->index(['user_id', 'is_default']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('addresses');
    }
};
