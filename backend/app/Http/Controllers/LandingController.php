<?php

namespace App\Http\Controllers;

use App\Models\LandingPage;
use Illuminate\Support\Facades\Storage;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\StreamedResponse;

class LandingController extends Controller
{
    public function index(): View
    {
        $page = LandingPage::current();

        return view('landing.index', ['content' => $page->texts(), 'images' => $page->imageUrls()]);
    }

    public function order(): View
    {
        return view('landing.order');
    }

    public function legal(string $document): View
    {
        $policy = config('legal.pages.'.$document);
        abort_unless(is_array($policy), 404);
        $content = LandingPage::current()->texts();
        $content['meta_title'] = $policy['title'].' · ToroGo';
        $content['meta_description'] = $policy['description'];

        return view('landing.legal', compact('policy', 'content', 'document'));
    }

    public function image(string $slot): StreamedResponse
    {
        abort_unless(array_key_exists($slot, config('landing.images')), 404);
        $path = LandingPage::current()->images[$slot] ?? null;
        abort_unless($path && Storage::disk('public')->exists($path), 404);
        $response = Storage::disk('public')->response($path, null, ['X-Content-Type-Options' => 'nosniff']);

        return $response;
    }
}
