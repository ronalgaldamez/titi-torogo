<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Una direccion guardada por el cliente.
 *
 * La biblia pide "Multiples direcciones guardadas": el cliente no escribe su
 * direccion en cada pedido, elige una de las que ya tiene.
 */
class Address extends Model
{
    use HasFactory, SoftDeletes;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'label',
        'address',
        'reference',
        'latitude',
        'longitude',
    ];

    /*
     * 'user_id' NO es fillable: sale de la sesion. Si lo fuera, alguien
     * podria crearle direcciones a otro usuario.
     *
     * 'is_default' tampoco: lo maneja el servidor, porque solo puede haber
     * UNA por usuario. Marcar una nueva tiene que desmarcar la anterior, y
     * eso no es algo que se pueda confiar a lo que mande el cliente.
     */

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            // float a proposito, igual que en Restaurant: las coordenadas se
            // mandan al mapa de Flutter, y un string obligaria a parsearlo
            // alla. La columna sigue siendo decimal(10,7), que es la que
            // guarda la precision.
            'latitude' => 'float',
            'longitude' => 'float',

            'is_default' => 'boolean',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
