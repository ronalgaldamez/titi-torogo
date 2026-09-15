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
            'is_available' => 'boolean',
            'sort_order' => 'integer',
        ];
    }

    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(MenuCategory::class, 'menu_category_id');
    }
}
