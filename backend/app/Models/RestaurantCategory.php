<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class RestaurantCategory extends Model
{
    protected function casts(): array
    {
        return ['is_active' => 'boolean', 'sort_order' => 'integer'];
    }
}
