<?php

namespace App\Http\Requests\Admin;

use App\Models\LandingPage;
use Illuminate\Foundation\Http\FormRequest;

class LandingPageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Las rutas exigen sesión de administrador.
    }

    public function rules(): array
    {
        $slots = implode(',', array_keys(config('landing.images')));
        $rules = ['content' => ['required', 'array:'.implode(',', array_keys(LandingPage::defaults()))],
            'images' => ['sometimes', 'array:'.$slots], 'remove_images' => ['sometimes', 'array:'.$slots]];
        foreach (LandingPage::defaults() as $key => $value) {
            $rules['content.'.$key] = $key === 'contact_email'
                ? ['nullable', 'email', 'max:255']
                : ['required', 'string', 'max:1200'];
        }
        foreach (array_keys(config('landing.images')) as $slot) {
            $rules['images.'.$slot] = ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:3072', 'dimensions:max_width=3000,max_height=3000'];
            $rules['remove_images.'.$slot] = ['sometimes', 'boolean'];
        }

        return $rules;
    }

    public function attributes(): array
    {
        $names = [];
        foreach (config('landing.sections') as $group => $fields) {
            foreach ($fields as $key => $field) {
                $names['content.'.$key] = $group.': '.$field[0];
            }
        }

        return $names;
    }

    public function messages(): array
    {
        return ['required' => 'Completá :attribute.', 'string' => ':attribute debe ser texto.',
            'max' => ':attribute supera el tamaño permitido (:max).', 'email' => 'Escribí un correo válido.',
            'image' => 'Elegí una imagen válida.', 'mimes' => 'Usá JPG, PNG o WebP.',
            'dimensions' => 'La imagen no puede superar 3000 × 3000 píxeles.'];
    }
}
