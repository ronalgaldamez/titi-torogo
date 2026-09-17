<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Agrega el perfil del usuario a la tabla users.
     *
     * Se hace en una migracion NUEVA en vez de editar la original
     * (0001_01_01_000000_create_users_table) para no tener que borrar
     * la base de datos existente. `php artisan migrate` basta.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Por defecto 'client' porque es el unico perfil que se registra solo.
            // NOTA: en PostgreSQL la opcion ->after() se ignora; la columna
            // se agrega al final de la tabla. No afecta en nada.
            $table->string('role', 20)->default('client');

            // El AGENDS pide indices en columnas que se consultan seguido:
            // filtrar usuarios por perfil lo vamos a hacer constantemente
            // (listar motorizados disponibles, restaurantes activos, etc).
            $table->index('role');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['role']);
            $table->dropColumn('role');
        });
    }
};
