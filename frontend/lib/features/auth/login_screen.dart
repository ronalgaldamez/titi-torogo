import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import 'auth_repository.dart';

/// La pantalla de inicio de sesion.
///
/// Lenguaje visual tomado de la referencia 1: bloques de color plano,
/// fondo blanco calido, bordes muy redondeados y el boton principal en
/// coral (el color de "accion", no el de marca).
///
/// El logo de la marca NO se usa aqui: solo sirvio como referencia de
/// colores. Lo que va arriba es una FOTO, que es lo que da hambre.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onAuthenticated,
    required this.onSkip,
    super.key,
  });

  /// Login correcto: la app navega segun el PERFIL (el cliente al catalogo,
  /// el restaurante a su menu). Por eso recibe el usuario completo y no solo
  /// un aviso de "ya entro": el perfil es lo que decide a donde va.
  final ValueChanged<User> onAuthenticated;

  /// "Explorar sin cuenta": el Home es publico, asi que se puede mirar
  /// el catalogo sin registrarse. Pedir cuenta ANTES de mostrar algo es
  /// la forma mas rapida de perder usuarios.
  final VoidCallback onSkip;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  late final AuthRepository _repository;

  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = AuthRepository(ApiClient(), AuthStorage());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final AuthResult result = await _repository.login(
        email: _email.text.trim(),
        password: _password.text,
      );

      if (!mounted) {
        return;
      }

      widget.onAuthenticated(result.user);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        // SingleChildScrollView + SafeArea: cuando el teclado sube, la
        // pantalla se desplaza en vez de desbordar. Es exactamente el
        // problema que describe el AGENDS ("el boton queda tapado por
        // el teclado").
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              // En el navegador o en una tablet el formulario no se estira
              // a lo ancho de toda la pantalla.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                // Valida mientras el usuario escribe, no recien al enviar.
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _HeroPanel(),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Inicia sesion',
                      style: text.titleLarge?.copyWith(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Field(
                      controller: _email,
                      label: 'Correo',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.email],
                      validator: (String? value) {
                        final String email = (value ?? '').trim();

                        if (email.isEmpty) {
                          return 'Escribi tu correo.';
                        }

                        if (!email.contains('@') || !email.contains('.')) {
                          return 'Ese correo no parece valido.';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Field(
                      controller: _password,
                      label: 'Contrasena',
                      icon: Icons.lock_outline_rounded,
                      obscure: !_showPassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.navy,
                        ),
                        tooltip: _showPassword
                            ? 'Ocultar contrasena'
                            : 'Mostrar contrasena',
                      ),
                      validator: (String? value) {
                        if ((value ?? '').isEmpty) {
                          return 'Escribi tu contrasena.';
                        }

                        return null;
                      },
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _SubmitButton(loading: _loading, onPressed: _submit),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: _loading ? null : widget.onSkip,
                      child: Text(
                        'Explorar sin cuenta',
                        style: text.labelLarge?.copyWith(color: AppTheme.teal),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: Text(
                        'ToroGo - Tejutla, Chalatenango',
                        style: text.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La foto grande de arriba, con la marca encima.
///
/// El velo oscuro del final NO es un adorno: la foto tiene zonas claras
/// (la tabla de madera) y sin el, el texto blanco desaparece encima.
/// Es la tecnica estandar en apps con foto de fondo.
class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: 300,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(
              'assets/login.jpg',
              fit: BoxFit.cover,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Colors.black87],
                  stops: <double>[0.4, 1],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text.rich(
                    TextSpan(
                      children: <TextSpan>[
                        // Amarillo del pajarito y blanco: la marca se lee
                        // sobre la foto sin necesidad del logo.
                        TextSpan(
                          text: 'Toro',
                          style: TextStyle(color: AppTheme.yellow),
                        ),
                        const TextSpan(
                          text: 'Go',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    style: text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tu nueva forma de pedir y recibir.',
                    style: text.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de texto con el estilo de la app.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscure = false,
    this.suffix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscure,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(color: AppTheme.navy),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.navy),
        prefixIcon: Icon(icon, color: AppTheme.teal),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.image),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.image),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.image),
          borderSide: const BorderSide(color: AppTheme.teal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.image),
          borderSide: const BorderSide(color: AppTheme.coral, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.image),
          borderSide: const BorderSide(color: AppTheme.coral, width: 2),
        ),
      ),
    );
  }
}

/// Mensaje de error del servidor, en coral.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEAE5),
        borderRadius: BorderRadius.circular(AppRadius.image),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.coral,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.coral,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El boton principal, en coral (el color de accion).
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.coral,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppTheme.coral,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.image),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text('Iniciar sesion'),
    );
  }
}
