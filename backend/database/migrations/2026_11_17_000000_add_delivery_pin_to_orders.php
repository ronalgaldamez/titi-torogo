<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->text('delivery_pin')->nullable();
            $table->unsignedBigInteger('delivery_verified_by')->nullable();
            $table->string('delivery_verification_reason', 500)->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint $table): void {
            $table->dropColumn(['delivery_pin', 'delivery_verified_by', 'delivery_verification_reason']);
        });
    }
};
