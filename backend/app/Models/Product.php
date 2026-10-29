<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Un plato del menu.
 */
class Product extends Model
{
    use HasFactory, SoftDeletes;

    // Las ofertas conservan su instante aunque PHP y PostgreSQL usen zonas distintas.
    protected $dateFormat = 'Y-m-d H:i:sP';

    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'description',
        'price',
        'image_path',
        'sort_order',
    ];

    /*
     * NO fillable, por el mismo criterio que 'role' en User:
     *
     *   restaurant_id    -> lo asigna el servidor desde la sesion del
     *                       restaurante; si fuera fillable, alguien podria
     *                       meter productos en el menu de otro restaurante
     *   menu_category_id -> idem, y ademas debe pertenecer al mismo restaurante
     *   is_available     -> lo cambia el restaurante con un endpoint propio
     *                       ("se me acabaron las pupusas de chicharron")
     */

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            // decimal:2 -> viaja como texto ("1.25") y nunca como float.
            'price' => 'decimal:2',
            'sale_price' => 'decimal:2',
            'offer_enabled' => 'boolean',
            'offer_starts_at' => 'immutable_datetime',
            'offer_ends_at' => 'immutable_datetime',
            'is_available' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    public function effectivePrice(?\Carbon\CarbonInterface $at = null): string
    {
        $at ??= now();
        return $this->offer_enabled && $this->sale_price !== null
            && $this->offer_starts_at !== null && $this->offer_ends_at !== null
            && $at->greaterThanOrEqualTo($this->offer_starts_at)
            && $at->lessThan($this->offer_ends_at)
            && bccomp($this->sale_price, $this->price, 2) < 0
                ? $this->sale_price : $this->price;
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(MenuCategory::class, 'menu_category_id');
    }
}
