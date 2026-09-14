<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

/**
 * Una categoria del menu: "Tipicos", "Bebidas", "Postres"...
 */
class MenuCategory extends Model
{
    use HasFactory, SoftDeletes;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'sort_order',
    ];

    /*
     * 'restaurant_id' NO es fillable: lo asigna el servidor desde la sesion
     * del restaurante autenticado. Si fuera fillable, un restaurante podria
     * mandar el id de otro y meterle categorias en su menu.
     */

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'sort_order' => 'integer',
        ];
    }

    public function restaurant(): BelongsTo
    {
        return $this->belongsTo(Restaurant::class);
    }

    /**
     * Los productos de esta categoria, ya ordenados.
     */
    public function products(): HasMany
    {
        return $this->hasMany(Product::class)->orderBy('sort_order');
    }
}
