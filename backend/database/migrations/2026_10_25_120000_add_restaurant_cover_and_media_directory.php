<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('restaurants', function (Blueprint $table) {
            $table->string('cover_path')->nullable();
            $table->string('media_directory')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('restaurants', function (Blueprint $table) {
            $table->dropColumn(['cover_path', 'media_directory']);
        });
    }
};
