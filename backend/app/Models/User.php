<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use App\Enums\UserRole;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * OJO: 'role' NO esta en esta lista a proposito. Si estuviera, un cliente
     * podria mandar {"role": "admin"} al registrarse y volverse administrador.
     * El perfil se asigna SIEMPRE de forma explicita:  $user->role = UserRole::Client;
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'role' => UserRole::class,
        ];
    }

    /**
     * ¿El usuario tiene alguno de estos perfiles?
     *
     * Uso:  $user->hasRole(UserRole::Admin)
     *       $user->hasRole(UserRole::Restaurant, UserRole::Admin)
     */
    public function hasRole(UserRole ...$roles): bool
    {
        return in_array($this->role, $roles, true);
    }

    /**
     * El restaurante de esta cuenta.
     *
     * Solo tiene sentido cuando role = Restaurant; en los otros tres perfiles
     * devuelve null. El login vive aqui y la info comercial en Restaurant.
     */
    public function restaurant(): HasOne
    {
        return $this->hasOne(Restaurant::class);
    }
}
