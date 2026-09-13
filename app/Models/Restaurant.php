<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * La informacion comercial de un restaurante.
 *
 * El login vive en User (relacion user_id); aqui esta lo que ve el cliente
 * en el Home: nombre, logo, direccion, coordenadas y tiempos.
 */
class Restaurant extends Model
{
    use HasFactory, SoftDeletes;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'description',
        'address',
        'phone',
        'latitude',
        'longitude',
        'logo_path',
        'prep_time_minutes',
        'delivery_fee',
    ];

    /*
     * OJO: estos NO son fillable a proposito, por el mismo criterio que
     * 'role' en User — nadie los cambia mandando un JSON:
     *
     *   user_id   -> se asigna al crear el restaurante desde el panel
     *   is_active -> lo controla SOLO el administrador
     *   is_open   -> lo cambia el restaurante desde su dashboard
     *   is_busy   -> idem (modo "muy ocupado")
     */

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            // float a proposito: el Home manda coordenadas a Flutter para
            // dibujar el mapa, y un string obligaria a parsearlo alla.
            'latitude' => 'float',
            'longitude' => 'float',

            // delivery_fee SI queda como decimal (string en JSON): el dinero
            // nunca se maneja con float, o aparecen centavos fantasma.
            'delivery_fee' => 'decimal:2',

            'prep_time_minutes' => 'integer',
            'is_active' => 'boolean',
            'is_open' => 'boolean',
            'is_busy' => 'boolean',
        ];
    }

    /**
     * La cuenta con la que este restaurante entra a la app.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Tiempo de entrega estimado que ve el cliente.
     *
     * El AGENDS dice que el modo "muy ocupado" alarga los tiempos:
     * cuando esta activo se suma un 50% mas.
     */
    public function estimatedDeliveryMinutes(): int
    {
        $base = $this->prep_time_minutes;

        return $this->is_busy ? (int) round($base * 1.5) : $base;
    }
}
