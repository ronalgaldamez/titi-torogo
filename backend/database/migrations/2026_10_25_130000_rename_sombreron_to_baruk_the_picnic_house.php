<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::transaction(function () {
            $user = DB::table('users')->where('email', 'sombreron@torogo.local')->first();
            if (! $user) {
                return;
            }
            $previous = ['El Sombreron Guanaco', 'El Sombrerón Guanaco', 'Baruk'];
            $changed = DB::table('restaurants')->where('user_id', $user->id)
                ->whereIn('name', $previous)
                ->update(['name' => 'Baruk the picnic house', 'updated_at' => now()]);

            if ($changed) {
                DB::table('users')->where('id', $user->id)->whereIn('name', $previous)
                    ->update(['name' => 'Baruk the picnic house', 'updated_at' => now()]);
            }
        });
    }

    public function down(): void
    {
        // Un rollback de esquema no debe devolver el nombre anterior de un negocio real.
    }
};
