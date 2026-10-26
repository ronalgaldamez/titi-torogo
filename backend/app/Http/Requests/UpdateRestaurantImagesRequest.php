<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateRestaurantImagesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'logo' => ['required_without:cover', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120', 'dimensions:max_width=6000,max_height=6000'],
            'cover' => ['required_without:logo', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120', 'dimensions:max_width=6000,max_height=6000'],
        ];
    }

    public function messages(): array
    {
        return [
            '*.required_without' => 'Seleccioná un logo o una portada.',
            '*.image' => 'El archivo debe ser una imagen válida.',
            '*.mimes' => 'Usá una imagen PNG, JPG o WebP.',
            '*.max' => 'Cada imagen puede pesar hasta 5 MB.',
            '*.dimensions' => 'La imagen no puede superar 6000 píxeles de ancho o alto.',
        ];
    }
}
