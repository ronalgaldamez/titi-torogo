<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Zonas de reparto.
     *
     * Una zona es un poligono dibujado en Google My Maps. El Home del cliente
     * no pregunta "¿que restaurantes estan cerca?" sino "¿que restaurantes
     * puedo entregar en este punto?" — que es la pregunta correcta.
     */
    public function up(): void
    {
        Schema::create('delivery_zones', function (Blueprint $table) {
            $table->id();
            $table->string('name');

            // El poligono en GeoJSON:
            //   {"type":"Polygon","coordinates":[[[lon,lat],[lon,lat],...]]}
            // OJO: GeoJSON siempre guarda longitud primero, latitud despues.
            //
            // jsonb y no json: PostgreSQL lo almacena en binario, y eso
            // permite indexarlo y consultarlo si algun dia lo necesitamos.
            $table->jsonb('polygon');

            // Tarifa de envio de la zona. El AGENDS la lista en el panel
            // de admin ("Tarifas de envio"), asi que vive aqui y no en el
            // restaurante.
            $table->decimal('delivery_fee', 8, 2)->default(0);

            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('delivery_zones');
    }
};
