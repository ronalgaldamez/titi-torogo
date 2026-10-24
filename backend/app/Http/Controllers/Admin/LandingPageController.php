<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\Admin\LandingPageRequest;
use App\Models\LandingPage;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

class LandingPageController extends Controller
{
    public function edit(): View
    {
        $page = LandingPage::current();

        return view('admin.landing.edit', ['content' => $page->texts(), 'images' => $page->imageUrls()]);
    }

    public function update(LandingPageRequest $request): RedirectResponse
    {
        $uploaded = [];
        $oldPaths = [];
        try {
            foreach (array_keys(config('landing.images')) as $slot) {
                if ($request->hasFile('images.'.$slot)) {
                    $path = $request->file('images.'.$slot)->store('landing', 'public');
                    if ($path === false) {
                        throw ValidationException::withMessages(['images.'.$slot => 'No se pudo guardar la imagen. Intentá de nuevo.']);
                    }
                    $uploaded[$slot] = $path;
                }
            }
            DB::transaction(function () use ($request, $uploaded, &$oldPaths): void {
                LandingPage::firstOrCreate(['slug' => 'home']);
                $page = LandingPage::where('slug', 'home')->lockForUpdate()->firstOrFail();
                $images = $page->images ?? [];
                foreach (array_keys(config('landing.images')) as $slot) {
                    if (isset($uploaded[$slot]) || $request->boolean('remove_images.'.$slot)) {
                        if (isset($images[$slot])) {
                            $oldPaths[] = $images[$slot];
                        }
                        $images[$slot] = $uploaded[$slot] ?? null;
                    }
                }
                $page->content = $request->validated('content');
                $page->images = $images;
                $page->save();
            });
        } catch (\Throwable $error) {
            Storage::disk('public')->delete(array_values($uploaded));
            throw $error;
        }
        Storage::disk('public')->delete($oldPaths);

        return redirect()->route('admin.landing.edit')->with('status', 'Página web actualizada. Los cambios ya están publicados en la landing.');
    }
}
