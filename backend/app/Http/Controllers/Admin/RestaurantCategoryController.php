<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\RestaurantCategoryRequest;
use App\Models\RestaurantCategory;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\View;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class RestaurantCategoryController extends Controller
{
    public function index(): View
    {
        return view('admin.categories.index', [
            'categories' => RestaurantCategory::orderBy('sort_order')->orderBy('id')->paginate(25),
        ]);
    }

    public function create(): View
    {
        $category = new RestaurantCategory;
        $category->is_active = true;
        $category->sort_order = 0;

        return view('admin.categories.form', compact('category'));
    }

    public function edit(RestaurantCategory $category): View
    {
        return view('admin.categories.form', compact('category'));
    }

    public function store(RestaurantCategoryRequest $request): RedirectResponse
    {
        return $this->save($request, new RestaurantCategory);
    }

    public function update(RestaurantCategoryRequest $request, RestaurantCategory $category): RedirectResponse
    {
        return $this->save($request, $category);
    }

    private function save(RestaurantCategoryRequest $request, RestaurantCategory $category): RedirectResponse
    {
        $newPath = null;
        if ($request->hasFile('icon')) {
            $newPath = $request->file('icon')->store('category-icons', 'public');
            if ($newPath === false) {
                return back()->withInput()->withErrors(['icon' => 'No se pudo guardar el icono. Intentá de nuevo.']);
            }
        }
        $oldPath = null;
        try {
            DB::transaction(function () use ($request, $category, $newPath, &$oldPath) {
                $model = $category->exists
                    ? RestaurantCategory::lockForUpdate()->findOrFail($category->id)
                    : $category;
                $model->name = $request->validated('name');
                $model->normalized_name = $request->validated('normalized_name');
                $model->sort_order = $request->validated('sort_order');
                $model->is_active = $request->boolean('is_active');
                if ($newPath !== null || $request->boolean('remove_icon')) {
                    $oldPath = $model->icon_path;
                    $model->icon_path = $newPath;
                }
                $model->save();
            });
        } catch (\Throwable $error) {
            if ($newPath !== null) {
                Storage::disk('public')->delete($newPath);
            }
            throw $error;
        }
        if ($oldPath !== null) {
            Storage::disk('public')->delete($oldPath);
        }

        return redirect()->route('admin.categories.index')->with('status', 'Categoría guardada.');
    }
}
