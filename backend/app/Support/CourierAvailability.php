<?php

namespace App\Support;

use App\Enums\OrderStatus;
use App\Enums\UserRole;
use App\Models\Restaurant;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;

class CourierAvailability
{
    public const RADIUS_KM = 5.0;

    public static function key(int $userId): string
    {
        return "courier-presence:{$userId}";
    }

    public static function near(Restaurant $restaurant): bool
    {
        $couriers = User::query()
            ->where('role', UserRole::Courier->value)
            ->where('is_active', true)->where('is_available', true)
            ->whereDoesntHave('courierOrders', fn ($query) => $query
                ->whereNotIn('status', OrderStatus::finalValues()))
            ->get(['id']);

        // shortcut: se recorren los motoristas libres; usar un índice geográfico si crece la flota.
        foreach ($couriers as $courier) {
            $position = Cache::get(self::key($courier->id));
            if ($position !== null
                && Carbon::parse($position['received_at'])->gt(now()->subMinutes(2))
                && Carbon::parse($position['captured_at'])->gt(now()->subMinutes(2))
                && Geometry::distanceKm(
                    $restaurant->latitude, $restaurant->longitude,
                    $position['latitude'], $position['longitude'],
                ) <= self::RADIUS_KM) {
                return true;
            }
        }

        return false;
    }
}
