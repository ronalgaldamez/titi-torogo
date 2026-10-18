<?php

namespace App\Http\Controllers\Api;

use App\Enums\OrderStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateCourierLocationRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

class CourierLocationController extends Controller
{
    public function update(UpdateCourierLocationRequest $request, int $order): JsonResponse
    {
        return DB::transaction(function () use ($request, $order) {
            $model = $request->user()->courierOrders()->lockForUpdate()->findOrFail($order);
            abort_unless(in_array($model->status, [OrderStatus::Ready, OrderStatus::PickedUp], true), 409, 'Este pedido ya no admite seguimiento GPS.');
            $key = "courier-location:{$model->id}:{$model->courier_id}";
            $previous = Cache::get($key);
            $captured = Carbon::parse($request->validated('captured_at'));
            if ($previous !== null && Carbon::parse($previous['captured_at'])->gte($captured)) {
                return response()->json(['accepted' => false]);
            }
            // Solo la última posición, durante dos minutos; no se crea un historial de movimientos.
            Cache::put($key, [
                'latitude' => (float) $request->validated('latitude'),
                'longitude' => (float) $request->validated('longitude'),
                'accuracy' => (float) $request->validated('accuracy'),
                'captured_at' => $captured->toISOString(),
                'received_at' => now()->toIso8601String(),
            ], now()->addMinutes(2));

            return response()->json(['accepted' => true]);
        });
    }

    public function show(Request $request, int $order): JsonResponse
    {
        $model = $request->user()->orders()->findOrFail($order);
        $active = $model->courier_id !== null
            && in_array($model->status, [OrderStatus::Ready, OrderStatus::PickedUp], true);
        $location = $active ? Cache::get("courier-location:{$model->id}:{$model->courier_id}") : null;
        if ($location !== null && Carbon::parse($location['captured_at'])->lt(now()->subMinutes(2))) {
            $location = null;
        }

        return response()->json([
            'order_id' => $model->id,
            'courier_id' => $active ? $model->courier_id : null,
            'status' => $model->status->value,
            'location' => $location,
        ])->header('Cache-Control', 'private, no-store');
    }
}
