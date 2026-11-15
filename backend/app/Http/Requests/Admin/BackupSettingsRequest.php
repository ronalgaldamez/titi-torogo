<?php

namespace App\Http\Requests\Admin;

use Illuminate\Foundation\Http\FormRequest;

class BackupSettingsRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return ['enabled' => ['required', 'boolean'], 'time' => ['required', 'date_format:H:i']];
    }
}
