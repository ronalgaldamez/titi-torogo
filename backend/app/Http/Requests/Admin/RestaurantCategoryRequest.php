<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class RestaurantCategoryRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // Las rutas están protegidas por auth y admin.
    }

    protected function prepareForValidation(): void
    {
        if (is_string($this->input('name'))) {
            $name = Str::squish($this->input('name'));
            $this->merge(['name' => $name, 'normalized_name' => Str::lower($name)]);
        } else {
            $this->merge(['normalized_name' => null]);
        }
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:80'],
            'normalized_name' => ['required', 'string', 'max:80', Rule::unique('restaurant_categories')->ignore($this->route('category'))],
            'sort_order' => ['required', 'integer', 'between:0,9999'],
            'is_active' => ['required', 'boolean'],
            'icon' => ['nullable', 'image', 'mimes:png,jpg,jpeg,webp', 'max:2048', 'dimensions:max_width=1024,max_height=1024'],
            'remove_icon' => ['sometimes', 'boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'normalized_name.unique' => 'Ya existe una categoría con ese nombre.',
            'icon.image' => 'Elegí una imagen válida para el icono.',
            'icon.mimes' => 'Usá PNG, JPG o WebP.',
            'icon.max' => 'El icono no puede superar 2 MB.',
            'icon.dimensions' => 'El icono no puede superar 1024 × 1024 píxeles.',
        ];
    }
}
