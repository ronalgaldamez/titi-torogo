<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LandingPage extends Model
{
    protected $fillable = ['slug'];

    protected function casts(): array
    {
        return ['content' => 'array', 'images' => 'array'];
    }

    public static function defaults(): array
    {
        return collect(config('landing.sections'))->flatMap(
            fn (array $fields) => collect($fields)->map(fn (array $field) => $field[1]),
        )->all();
    }

    public static function current(): self
    {
        return static::where('slug', 'home')->first() ?? new static(['slug' => 'home']);
    }

    public function texts(): array
    {
        $defaults = static::defaults();
        $texts = array_replace($defaults, $this->content ?? []);
        $texts['contact_email'] = $texts['contact_email'] ?: $defaults['contact_email'];

        return $texts;
    }

    public function imageUrls(): array
    {
        return collect(config('landing.images'))->map(function (array $image, string $slot): string {
            $path = $this->images[$slot] ?? null;

            return $path ? route('landing.image', ['slot' => $slot, 'v' => sha1($path)]) : asset($image['default']);
        })->all();
    }
}
