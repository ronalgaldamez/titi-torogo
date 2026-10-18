<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateRestaurantCategoriesRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'category_ids' => ['present', 'array', 'max:100'],
            'category_ids.*' => ['required', 'integer', 'distinct', 'exists:restaurant_categories,id'],
        ];
    }
}
