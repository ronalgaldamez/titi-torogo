<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Productos del menu.
     */
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();

            $table->foreignId('restaurant_id')->constrained()->cascadeOnDelete();

            // nullOnDelete y no cascade: si el restaurante borra una categoria,
            // sus productos NO deben desaparecer. Quedan sin categoria y el
            // restaurante los reacomoda.
            $table->foreignId('menu_category_id')->nullable()->constrained()->nullOnDelete();

            $table->string('name');
            $table->text('description')->nullable();

            // decimal y no float: el precio nunca se maneja con float o
            // aparecen centavos fantasma al sumar el carrito.
            $table->decimal('price', 8, 2);

            // Foto del plato, guardada en MinIO.
            $table->string('image_path')->nullable();

            // El restaurante puede agotar un plato sin borrarlo del menu.
            // Igual que 'is_open', NO es fillable.
            $table->boolean('is_available')->default(true);

            $table->unsignedSmallInteger('sort_order')->default(0);

            $table->timestamps();
            $table->softDeletes();

            $table->index(['restaurant_id', 'is_available']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
