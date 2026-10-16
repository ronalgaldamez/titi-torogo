<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            // Null conserva intactos los pedidos anteriores a esta función.
            $table->timestamp('acceptance_expires_at')->nullable();
            $table->string('cancellation_reason')->nullable();
            $table->index(['status', 'acceptance_expires_at']);
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table) {
            $table->dropIndex(['status', 'acceptance_expires_at']);
            $table->dropColumn(['acceptance_expires_at', 'cancellation_reason']);
        });
    }
};
