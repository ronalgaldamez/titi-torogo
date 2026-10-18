<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('restaurant_categories', function (Blueprint $table) {
            $table->string('icon_key', 30)->default('restaurant');
            $table->string('icon_path')->nullable();
        });
        foreach (['hamburguesas' => 'burger', 'pollo' => 'menu', 'tacos' => 'fastfood', 'comida típica' => 'rice'] as $name => $icon) {
            DB::table('restaurant_categories')->where('normalized_name', $name)->update(['icon_key' => $icon]);
        }
    }

    public function down(): void
    {
        Schema::table('restaurant_categories', function (Blueprint $table) {
            $table->dropColumn(['icon_key', 'icon_path']);
        });
    }
};
