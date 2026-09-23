<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * El pedido: el corazon de ToroGo.
     *
     * Recorrido de estados (biblia, "Flujo de pedido"):
     *
     *   pending -> accepted -> preparing -> ready -> picked_up -> delivered
     *
     * y dos finales por el costado: rejected (el restaurante dijo que no) y
     * cancelled (lo corto alguien, tipicamente el admin).
     */
    public function up(): void
    {
        Schema::create('orders', function (Blueprint $table) {
            $table->id();

            // Quien pide, quien cocina y quien lleva.
            // El motorizado arranca en null: el pedido nace SIN repartidor y
            // se asigna cuando uno lo toma de la lista de disponibles.
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('restaurant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('courier_id')
                ->nullable()
                ->constrained('users')  // sin esto Laravel buscaria 'couriers'
                ->nullOnDelete();

            // De que direccion guardada salio. Puede quedar en null si el
            // cliente borra esa direccion, y esta bien: el pedido no depende
            // de ella, porque abajo va la copia.
            $table->foreignId('address_id')->nullable()->constrained()->nullOnDelete();

            // COPIA de la direccion al momento de pedir.
            //
            // Es la decision que evita reescribir la historia: si el cliente
            // edita su direccion la semana que viene, este pedido sigue
            // diciendo a donde se entrego DE VERDAD. Con solo el address_id,
            // el historial cambiaria solo.
            $table->string('delivery_address');
            $table->string('delivery_reference')->nullable();
            $table->decimal('delivery_latitude', 10, 7);
            $table->decimal('delivery_longitude', 10, 7);

            // pending, accepted, preparing, ready, picked_up, delivered,
            // rejected, cancelled.
            //
            // String y no un enum de PostgreSQL a proposito: agregar un estado
            // nuevo no deberia necesitar una migracion. La lista valida vive
            // en el enum de PHP (App\Enums\OrderStatus), que es donde se puede
            // leer y cambiar.
            $table->string('status', 20)->default('pending');

            // Dinero: decimal(8,2), NUNCA float. Es la misma regla que ya
            // rige en productos y zonas: con float aparecen centavos fantasma.
            $table->decimal('subtotal', 8, 2);

            // El envio se guarda DESGLOSADO, que es como lo ve el cliente en
            // el checkout y como se reparte despues:
            //   courier_fee  -> lo que se lleva el motorizado
            //   platform_fee -> lo que se queda ToroGo
            //   delivery_fee -> la suma de los dos (lo que paga el cliente)
            $table->decimal('delivery_fee', 8, 2);
            $table->decimal('courier_fee', 8, 2);
            $table->decimal('platform_fee', 8, 2);

            $table->decimal('total', 8, 2);

            // MVP: solo efectivo. La biblia no quiere pasarela todavia.
            $table->string('payment_method', 20)->default('cash');

            $table->string('notes')->nullable();

            // LA CLAVE CONTRA EL DOBLE COBRO.
            //
            // La biblia lo pide como "Idempotencia (evitar doble cobro):
            // tokens unicos, cada transaccion tiene un ID unico". La app
            // genera una clave por checkout; si la peticion llega DOS veces
            // (doble toque, reintento por mala senal), el segundo intento no
            // crea otro pedido: devuelve el mismo.
            //
            // Unico en toda la tabla, no por usuario: dos personas distintas
            // tampoco pueden usar la misma clave.
            $table->string('idempotency_key', 64)->unique();

            // El recorrido del pedido. Null = todavia no paso por ahi.
            $table->timestamp('accepted_at')->nullable();
            $table->timestamp('ready_at')->nullable();
            $table->timestamp('picked_up_at')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();

            $table->timestamps();
            $table->softDeletes();

            // Indices por donde se va a buscar de verdad, no "por si acaso":
            //   restaurante  -> su panel, filtrando por estado
            //   motorizado   -> su lista de pedidos
            //   cliente      -> "Mis pedidos", del mas nuevo al mas viejo
            //   status       -> la lista de disponibles para motorizados
            $table->index(['restaurant_id', 'status']);
            $table->index(['courier_id', 'status']);
            $table->index(['user_id', 'created_at']);
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
