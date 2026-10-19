<?php

namespace App\Http\Requests\Auth;

use App\Enums\UserRole;
use Illuminate\Foundation\Http\FormRequest;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()?->hasRole(UserRole::Client) ?? false;
    }

    protected function prepareForValidation(): void
    {
        $data = [];
        if (is_string($this->input('name'))) {
            $data['name'] = trim($this->input('name'));
        }
        if (is_string($this->input('phone'))) {
            $data['phone'] = preg_replace('/[\s-]+/u', '', $this->input('phone'));
            if ($data['phone'] === '') {
                $data['phone'] = null;
            }
        }
        $this->merge($data);
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'min:2', 'max:255'],
            'phone' => ['present', 'nullable', 'string', 'max:30', 'regex:/^(?:\+503)?[267][0-9]{7}$/'],
            'email' => ['prohibited'],
            'password' => ['prohibited'],
            'role' => ['prohibited'],
            'id' => ['prohibited'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'Escribí tu nombre.',
            'name.min' => 'El nombre debe tener al menos 2 caracteres.',
            'name.max' => 'El nombre no puede superar 255 caracteres.',
            'phone.regex' => 'Usá un teléfono de El Salvador de 8 dígitos, que comience con 2, 6 o 7.',
            'phone.string' => 'El teléfono debe enviarse como texto.',
            'phone.max' => 'El teléfono es demasiado largo.',
            'email.prohibited' => 'El correo no se puede cambiar desde el perfil.',
        ];
    }
}
