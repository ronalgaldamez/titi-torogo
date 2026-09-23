<?php

namespace App\Models;

use App\Enums\OrderStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Un pedido.
 *
 * Guarda COPIAS de la direccion (y de cada plato, ver OrderItem). Es lo que
 * hace que el historial no se reescriba solo: si el cliente cambia su
 * direccion o el restaurante sube un precio, este pedido sigue contando lo
 * que paso de verdad ese dia.
 */
class Order extends Model
{
    use HasFactory, SoftDeletes;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'notes',
    ];

    /*
     * Todo lo demas se asigna explicito, cada uno por su razon:
     *
     *   user_id         -> sale de la sesion
     *   restaurant_id   -> se valida contra el carrito
     *   courier_id      -> lo pone el motorizado al tomar el pedido
     *   status          -> solo se mueve por transiciones validas (moveTo)
     *   subtotal, total -> los CALCULA el servidor desde el catalogo
     *   payment_method  -> hoy siempre 'cash'
     *   *_at            -> las marca el cambio de estado
     *   idempotency_key -> la genera o la valida el servidor
     */

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status' => OrderStatus::class,

            // decimal:2 -> el dinero viaja como TEXTO ("10.50"), nunca como
            // float. Las sumas se hacen con bcadd.
            'subtotal' => 'decimal:2',
            'delivery_fee' => 'decimal:2',
            'courier_fee' => 'decimal:2',
            'platform_fee' => 'decimal:2',
            'total' => 'decimal:2',

            // Las coordenadas de la copia, para pintar el punto en el mapa.
            'delivery_latitude' => 'float',
            'delivery_longitude' => 'float',

            'accepted_at' => 'datetime',
            'ready_at' => 'datetime',
            'picked_up_at' => 'datetime',
            'delivered_at' => 'datetime',
            'cancelled_at' => 'datetime',
        ];
    }

    /**
     * El cliente que pidio.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    /**
     * El motorizado que lo lleva. Null hasta que alguien lo tome.
     */
    public function courier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'courier_id');
    }

    /**
     * La direccion guardada de la que salio. Puede ser null si el cliente la
     * borro despues; los datos de la entrega estan copiados en el pedido.
     */
    public function address(): BelongsTo
    {
        return $this->belongsTo(Address::class);
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    /**
     * ¿Sigue en curso?
     */
    public function isActive(): bool
    {
        return $this->status->isActive();
    }

    /**
     * Mueve el pedido a otro estado, si la transicion es legal.
     *
     * Devuelve false cuando no lo es, en vez de lanzar una excepcion: quien
     * llama decide que contestar (un 409 con un mensaje claro, por ejemplo).
     *
     * Marca la hora que corresponde al estado nuevo y NO guarda: el guardado
     * lo hace el controlador, para poder meter todo en una transaccion.
     */
    public function moveTo(OrderStatus $status): bool
    {
        if (! $this->status->canMoveTo($status)) {
            return false;
        }

        $this->status = $status;

        $column = $status->timestampColumn();

        if ($column !== null) {
            $this->{$column} = now();
        }

        return true;
    }
}
