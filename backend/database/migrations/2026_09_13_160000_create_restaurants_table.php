<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Restaurantes de ToroGo.
     *
     * La cuenta del restaurante vive en `users` (ahi esta el login) y su
     * informacion comercial vive aqui. Separados porque son dos cosas
     * distintas: la cuenta sirve para autenticarse, el restaurante para
     * mostrarse en el Home del cliente.
     */
    public function up(): void
    {
        Schema::create('restaurants', function (Blueprint $table) {
            $table->id();

            // unique: una cuenta = un restaurante. Las multiples sucursales
            // son Fase 2 ("Titi"), no las adelantemos.
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();

            $table->string('name');
            $table->text('description')->nullable();
            $table->string('address');
            $table->string('phone', 20);

            // Coordenadas para el filtro de cercania del Home del cliente.
            // decimal y no float: aqui los grados se guardan con precision
            // exacta y no arrastran error de redondeo. (En el modelo se
            // castean a float porque el error de un float64 a 7 decimales
            // es de centimetros, irrelevante para una direccion.)
            $table->decimal('latitude', 10, 7);
            $table->decimal('longitude', 10, 7);

            // Logo guardado en MinIO.
            $table->string('logo_path')->nullable();

            // El ADMINISTRADOR activa o desactiva un restaurante
            // (AGENDS: "Lista de restaurantes (crear, editar, activar/desactivar)").
            $table->boolean('is_active')->default(true);

            // El RESTAURANTE se abre/cierra y marca "muy ocupado".
            // Segun el AGENDS, el modo ocupado alarga los tiempos de entrega.
            $table->boolean('is_open')->default(false);
            $table->boolean('is_busy')->default(false);

            $table->unsignedSmallInteger('prep_time_minutes')->default(30);
            $table->decimal('delivery_fee', 8, 2)->default(0);

            $table->timestamps();

            // AGENDS: "Soft deletes: usar deleted_at en lugar de borrar registros".
            // Si un restaurante se va de ToroGo, sus pedidos historicos
            // siguen apuntando a el.
            $table->softDeletes();

            // El Home filtra por activo + abierto antes de ordenar por cercania.
            $table->index(['is_active', 'is_open']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('restaurants');
    }
};
