<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Categorias del menu de un restaurante.
     *
     * El AGENDS las lista como funcionalidad propia del restaurante
     * ("Categorias del menu"), asi que van en su tabla y no como un texto
     * suelto en cada producto: asi se pueden ordenar y renombrar de una vez.
     */
    public function up(): void
    {
        Schema::create('menu_categories', function (Blueprint $table) {
            $table->id();

            $table->foreignId('restaurant_id')->constrained()->cascadeOnDelete();

            $table->string('name');

            // Para que el restaurante ordene sus categorias como quiera
            // (Entradas, Platos fuertes, Postres, Bebidas...).
            $table->unsignedSmallInteger('sort_order')->default(0);

            $table->timestamps();
            $table->softDeletes();

            $table->index(['restaurant_id', 'sort_order']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('menu_categories');
    }
};
