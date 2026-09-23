<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * "Disponible / No disponible" del motorizado.
     *
     * Es el primer punto del Home del motorizado en la biblia.
     *
     * Va en 'users' y no en una tabla aparte porque el motorizado no tiene
     * ficha propia como el restaurante: es una cuenta con role = courier y
     * pocos datos mas. Una tabla de una sola columna seria ceremonia.
     *
     * Arranca en FALSE a proposito: nadie sale a repartir sin decir que si.
     * Si arrancara en true, un motorizado que abre la app por primera vez
     * empezaria a recibir pedidos sin haber aceptado trabajar.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_available')->default(false);
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('is_available');
        });
    }
};
