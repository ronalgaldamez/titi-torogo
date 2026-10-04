<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Los datos del motorizado: telefono, vehiculo y si el administrador lo tiene
 * activo.
 *
 * POR QUE VAN EN 'users' Y NO EN UNA TABLA APARTE
 *
 * Es la misma decision que ya se tomo con 'is_available' (ver la migracion
 * 2026_09_20_100300): el restaurante tiene ficha propia porque tiene menu,
 * horarios y tarifas; el motorizado no. Sus datos son tres columnas, y una
 * tabla para tres columnas es ceremonia de mas, ademas de obligar a un JOIN en
 * cada consulta del reparto.
 *
 * QUE SIGNIFICA is_active
 *
 * Es el "dar de baja" del administrador, y es distinto de is_available:
 *
 *   is_available -> lo maneja EL MOTORIZADO ("hoy salgo a repartir")
 *   is_active    -> lo maneja EL ADMINISTRADOR ("esta cuenta no trabaja mas")
 *
 * Arranca en TRUE porque todos los que ya existen estan trabajando: si naciera
 * en false, este cambio dejaria a los motorizados actuales sin poder entrar.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Nulo a proposito: la cuenta puede existir antes de tener el dato.
            $table->string('phone', 30)->nullable()->after('email');

            // 'moto', 'carro' o 'bicicleta'. Se guarda como texto y no como
            // enum de base de datos para poder agregar un vehiculo nuevo sin
            // una migracion (el que valida es App\Enums\Vehicle, en PHP).
            $table->string('vehicle', 20)->nullable()->after('phone');

            $table->boolean('is_active')->default(true)->after('is_available');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['phone', 'vehicle', 'is_active']);
        });
    }
};
