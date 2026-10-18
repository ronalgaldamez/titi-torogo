<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateCourierLocationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'accuracy' => ['required', 'numeric', 'between:0,100'],
            'captured_at' => ['required', 'date',
                'after_or_equal:'.now()->subSeconds(30)->toIso8601String(),
                'before_or_equal:'.now()->addSeconds(10)->toIso8601String()],
        ];
    }

    public function messages(): array
    {
        return [
            'accuracy.between' => 'Esperá una ubicación GPS con precisión de hasta 100 metros.',
            'captured_at.after_or_equal' => 'La ubicación es antigua. Actualizá el GPS.',
            'captured_at.before_or_equal' => 'Revisá la fecha y hora del teléfono.',
        ];
    }
}
