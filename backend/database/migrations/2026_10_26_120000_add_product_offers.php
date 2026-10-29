<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table): void {
            $table->boolean('offer_enabled')->default(false);
            $table->decimal('sale_price', 8, 2)->nullable();
            $table->timestampTz('offer_starts_at')->nullable();
            $table->timestampTz('offer_ends_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table): void {
            $table->dropColumn(['offer_enabled', 'sale_price', 'offer_starts_at', 'offer_ends_at']);
        });
    }
};
