<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Una linea de un pedido.
 *
 * 'name', 'unit_price' y 'subtotal' son COPIAS del plato al momento de la
 * compra, y las calcula el servidor leyendo el catalogo. El cliente solo manda
 * 'product_id' y 'quantity': el precio NUNCA se acepta desde afuera, o
 * cualquiera pediria una pupusa a un centavo.
 */
class OrderItem extends Model
{
    use HasFactory;

    /*
     * Sin SoftDeletes a proposito: una linea de pedido o esta o no esta.
     * Guardar lineas borradas solo complicaria las sumas del historial.
     */

    /**
     * @var list<string>
     */
    protected $fillable = [
        'product_id',
        'name',
        'unit_price',
        'quantity',
        'subtotal',
    ];

    /*
     * 'order_id' NO es fillable: se asigna desde la relacion
     * ($order->items()->createMany(...)). Asi una linea no puede terminar
     * colgando de un pedido ajeno por un id que venga en el JSON.
     */

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'unit_price' => 'decimal:2',
            'subtotal' => 'decimal:2',
            'quantity' => 'integer',
        ];
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    /**
     * El plato del catalogo. Puede ser null si el restaurante lo borro: la
     * linea se queda con su copia del nombre y el precio.
     */
    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
