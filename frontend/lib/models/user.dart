/// El usuario que devuelve la API al iniciar sesion.
///
/// Espeja app/Http/Resources/UserResource.php del backend. Si ese resource
/// cambia, este archivo cambia con el.
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.roleLabel,
  });

  final int id;
  final String name;
  final String email;

  /// Valor tecnico: 'client', 'restaurant', 'courier' o 'admin'.
  final String role;

  /// Etiqueta en espanol que manda el backend: 'Cliente', 'Motorizado'...
  /// Se usa para mostrar, nunca para decidir permisos.
  final String roleLabel;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      roleLabel: json['role_label'] as String,
    );
  }
}
