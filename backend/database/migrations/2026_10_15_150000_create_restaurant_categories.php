<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('restaurant_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name', 80);
            $table->string('normalized_name', 80)->unique();
            $table->unsignedInteger('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
        Schema::create('restaurant_category_assignments', function (Blueprint $table) {
            $table->foreignId('restaurant_id')->constrained()->cascadeOnDelete();
            $table->foreignId('restaurant_category_id')->constrained()->cascadeOnDelete();
            $table->primary(['restaurant_id', 'restaurant_category_id']);
        });
        // Conserva las opciones del inicio sin adivinar categorías de cada negocio.
        foreach (['Pupusas', 'Hamburguesas', 'Pollo', 'Tacos', 'Comida típica'] as $index => $name) {
            DB::table('restaurant_categories')->insert([
                'name' => $name, 'normalized_name' => Str::lower($name),
                'sort_order' => $index, 'created_at' => now(), 'updated_at' => now(),
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('restaurant_category_assignments');
        Schema::dropIfExists('restaurant_categories');
    }
};
