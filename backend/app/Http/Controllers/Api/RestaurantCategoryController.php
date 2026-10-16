<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateRestaurantCategoriesRequest;
use App\Http\Resources\RestaurantCategoryResource;
use App\Http\Resources\RestaurantResource;
use App\Models\RestaurantCategory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class RestaurantCategoryController extends Controller
{
    public function icon(RestaurantCategory $category)
    {
        abort_unless($category->icon_path && Storage::disk('public')->exists($category->icon_path), 404);

        return Storage::disk('public')->response($category->icon_path, null, [
            'Cache-Control' => 'public, max-age=3600',
            'X-Content-Type-Options' => 'nosniff',
        ]);
    }

    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'categories' => RestaurantCategoryResource::collection(
                RestaurantCategory::where('is_active', true)->orderBy('sort_order')->orderBy('id')->get(),
            ),
            'selected_ids' => $request->user()->restaurant->categories()->pluck('restaurant_categories.id'),
        ]);
    }

    public function update(UpdateRestaurantCategoriesRequest $request): JsonResponse
    {
        return DB::transaction(function () use ($request) {
            $ids = $request->validated('category_ids');
            // Serializa con la desactivación del administrador antes de asignar.
            $active = RestaurantCategory::whereIn('id', $ids)->where('is_active', true)
                ->orderBy('id')->lockForUpdate()->get();
            if ($active->count() !== count($ids)) {
                throw ValidationException::withMessages([
                    'category_ids' => 'Una categoría ya no está disponible. Actualizá las opciones.',
                ]);
            }
            $restaurant = $request->user()->restaurant()->lockForUpdate()->firstOrFail();
            $restaurant->categories()->sync($ids);

            return response()->json([
                'restaurant' => new RestaurantResource($restaurant->load('categories')),
            ]);
        });
    }
}
