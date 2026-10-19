import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import 'auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.onAuthenticated,
    required this.onSkip,
    super.key,
  });
  final ValueChanged<User> onAuthenticated;
  final VoidCallback onSkip;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
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
    if (_loading) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.login(
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _Colors.background,
      ),
      child: Scaffold(
        backgroundColor: _Colors.background,
        body: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(child: _FoodPattern()),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 420,
                          minHeight: (constraints.maxHeight - 48).clamp(
                            0.0,
                            double.infinity,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: 'toro'),
                                      TextSpan(
                                        text: 'go',
                                        style: TextStyle(
                                          color: AppTheme.yellow,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '.',
                                        style: TextStyle(color: _Colors.accent),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    color: _Colors.paper,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                  ),
                                ),
                                const SizedBox(height: 42),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      color: AppTheme.yellow,
                                      size: 6,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'QUÉ BUENO TENERTE AQUÍ',
                                        style: TextStyle(
                                          color: _Colors.muted,
                                          fontSize: 11,
                                          letterSpacing: 1.4,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: 'Pedí cerca.\n'),
                                      TextSpan(
                                        text: 'Comé rico.',
                                        style: TextStyle(color: _Colors.accent),
                                      ),
                                    ],
                                  ),
                                  style: TextStyle(
                                    color: _Colors.paper,
                                    fontSize: 46,
                                    height: 1.08,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Tu próximo antojo\nestá más cerca.',
                                        style: TextStyle(
                                          color: _Colors.muted,
                                          height: 1.65,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Transform.rotate(
                                      angle: .15,
                                      child: const SizedBox(
                                        width: 90,
                                        height: 76,
                                        child: ExcludeSemantics(
                                          child: Stack(
                                            children: [
                                              Positioned(
                                                left: 0,
                                                top: 0,
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CustomPaint(
                                                    painter: _BagPainter(),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                left: 19,
                                                top: 34,
                                                child: Text(
                                                  'go.',
                                                  style: TextStyle(
                                                    color: AppTheme.yellow,
                                                    fontSize: 21,
                                                    height: 1,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -1,
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                right: 0,
                                                top: 0,
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CustomPaint(
                                                    painter: _SparkPainter(),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                AutofillGroup(
                                  child: Form(
                                    key: _formKey,
                                    autovalidateMode:
                                        AutovalidateMode.onUserInteraction,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _Field(
                                          controller: _email,
                                          label: 'Correo electrónico',
                                          hint: 'tu@correo.com',
                                          enabled: !_loading,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.email,
                                          ],
                                          suffix: const Icon(
                                            Icons.alternate_email,
                                            color: _Colors.muted,
                                            size: 20,
                                          ),
                                          validator: (value) {
                                            final email = (value ?? '').trim();
                                            if (email.isEmpty) {
                                              return 'Escribí tu correo.';
                                            }
                                            if (!email.contains('@') ||
                                                !email.contains('.')) {
                                              return 'Ese correo no parece válido.';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 22),
                                        _Field(
                                          controller: _password,
                                          label: 'Contraseña',
                                          hint: 'Tu contraseña',
                                          enabled: !_loading,
                                          obscure: !_showPassword,
                                          textInputAction: TextInputAction.done,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          onSubmitted: (_) => _submit(),
                                          suffix: IconButton(
                                            onPressed: _loading
                                                ? null
                                                : () => setState(
                                                    () => _showPassword =
                                                        !_showPassword,
                                                  ),
                                            tooltip: _showPassword
                                                ? 'Ocultar contraseña'
                                                : 'Mostrar contraseña',
                                            icon: Icon(
                                              _showPassword
                                                  ? Icons
                                                        .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: _Colors.muted,
                                              size: 20,
                                            ),
                                          ),
                                          validator: (value) =>
                                              (value ?? '').isEmpty
                                              ? 'Escribí tu contraseña.'
                                              : null,
                                        ),
                                        if (_error != null) ...[
                                          const SizedBox(height: 16),
                                          Semantics(
                                            liveRegion: true,
                                            child: Text(
                                              _error!,
                                              style: const TextStyle(
                                                color: _Colors.accent,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 30),
                                        FilledButton(
                                          onPressed: _loading ? null : _submit,
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _Colors.button,
                                            foregroundColor: _Colors.background,
                                            disabledBackgroundColor: _Colors
                                                .button
                                                .withValues(alpha: .6),
                                            padding: const EdgeInsets.fromLTRB(
                                              20,
                                              10,
                                              10,
                                              10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _loading
                                                      ? 'Un momento…'
                                                      : 'Vamos a lo rico',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color: _Colors.background,
                                                  borderRadius:
                                                      BorderRadius.circular(11),
                                                ),
                                                child: _loading
                                                    ? const Padding(
                                                        padding: EdgeInsets.all(
                                                          12,
                                                        ),
                                                        child:
                                                            CircularProgressIndicator(
                                                              color:
                                                                  _Colors.paper,
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.arrow_forward,
                                                        color: _Colors.paper,
                                                        size: 21,
                                                      ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: TextButton.icon(
                                    onPressed: _loading ? null : widget.onSkip,
                                    style: TextButton.styleFrom(
                                      foregroundColor: _Colors.paper,
                                      minimumSize: const Size(0, 48),
                                    ),
                                    icon: const Icon(
                                      Icons.explore_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Primero quiero explorar',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.favorite_border_rounded,
                                      color: _Colors.accent,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Flexible(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(text: 'Menos vueltas.\n'),
                                            TextSpan(
                                              text: 'Más de lo que te gusta.',
                                              style: TextStyle(
                                                color: _Colors.paper,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        style: TextStyle(
                                          color: _Colors.muted,
                                          fontSize: 12,
                                          height: 1.65,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 30),
                              child: Column(
                                children: [
                                  Divider(
                                    color: _Colors.paper.withValues(alpha: .15),
                                  ),
                                  const SizedBox(height: 12),
                                  const Row(
                                    children: [
                                      Text(
                                        'TOROGO',
                                        style: TextStyle(
                                          color: _Colors.muted,
                                          fontSize: 11,
                                          letterSpacing: 1.8,
                                        ),
                                      ),
                                      Spacer(),
                                      Flexible(
                                        child: Text(
                                          'Hecho para estar cerca.',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            color: _Colors.muted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Colors {
  static const background = Color(0xFF102E3C);
  static const paper = Color(0xFFFFF8ED);
  static const muted = Color(0xFFB0C0C6);
  static const accent = Color(0xFFFF825E);
  static const button = Color(0xFFF2613F);
}

// Los trazos finos reproducen la bolsa del canvas sin depender del icono sólido de Android.
class _BagPainter extends CustomPainter {
  const _BagPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()
      ..color = _Colors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(6, 2)
        ..lineTo(3, 6)
        ..lineTo(3, 20)
        ..quadraticBezierTo(3, 22, 5, 22)
        ..lineTo(19, 22)
        ..quadraticBezierTo(21, 22, 21, 20)
        ..lineTo(21, 6)
        ..lineTo(18, 2)
        ..close(),
      paint,
    );
    canvas.drawLine(const Offset(3, 6), const Offset(21, 6), paint);
    canvas.drawPath(
      Path()
        ..moveTo(8, 10)
        ..cubicTo(8, 15.3, 16, 15.3, 16, 10),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BagPainter oldDelegate) => false;
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;
    void star(double x, double y, double radius) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y - radius)
          ..lineTo(x + radius * .3, y - radius * .3)
          ..lineTo(x + radius, y)
          ..lineTo(x + radius * .3, y + radius * .3)
          ..lineTo(x, y + radius)
          ..lineTo(x - radius * .3, y + radius * .3)
          ..lineTo(x - radius, y)
          ..lineTo(x - radius * .3, y - radius * .3)
          ..close(),
        paint,
      );
    }

    star(size.width * .35, size.height * .63, size.width * .29);
    star(size.width * .8, size.height * .2, size.width * .13);
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => false;
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.enabled,
    required this.validator,
    required this.suffix,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool enabled;
  final bool obscure;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final Widget suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    obscureText: obscure,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    onFieldSubmitted: onSubmitted,
    validator: validator,
    autocorrect: false,
    enableSuggestions: !obscure,
    cursorColor: AppTheme.yellow,
    style: const TextStyle(color: _Colors.paper, fontSize: 16),
    decoration: InputDecoration(
      labelText: label.toUpperCase(),
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(
        color: _Colors.muted,
        fontSize: 12,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(color: _Colors.muted, fontSize: 16),
      errorStyle: const TextStyle(color: _Colors.accent),
      errorMaxLines: 3,
      filled: true,
      fillColor: _Colors.background.withValues(alpha: .8),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      suffixIcon: suffix,
      border: const UnderlineInputBorder(),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _Colors.paper.withValues(alpha: .35)),
      ),
      disabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _Colors.paper.withValues(alpha: .2)),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppTheme.yellow, width: 2),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _Colors.accent),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: _Colors.accent, width: 2),
      ),
    ),
  );
}

class _FoodPattern extends StatelessWidget {
  const _FoodPattern();
  static const _icons = [
    Icons.lunch_dining_outlined,
    Icons.local_pizza_outlined,
    Icons.coffee_outlined,
    Icons.icecream_outlined,
    Icons.bakery_dining_outlined,
    Icons.local_drink_outlined,
    Icons.cookie_outlined,
    Icons.set_meal_outlined,
    Icons.cake_outlined,
    Icons.egg_alt_outlined,
    Icons.ramen_dining_outlined,
    Icons.restaurant_outlined,
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = (constraints.maxWidth / 84).ceil();
      final rows = (constraints.maxHeight / 100).ceil();
      return Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (var row = 0; row < rows; row++)
            for (var column = 0; column < columns; column++)
              Positioned(
                left: column * 84.0 + (row.isOdd ? 25 : -8),
                top: row * 100.0 + (column.isOdd ? 22 : 0),
                child: Transform.rotate(
                  angle: ((row * 3 + column) % 5 - 2) * .18,
                  child: Icon(
                    _icons[(row * columns + column) % _icons.length],
                    size: (row + column).isEven ? 42 : 32,
                    color: _Colors.muted.withValues(alpha: .10),
                  ),
                ),
              ),
        ],
      );
    },
  );
}
