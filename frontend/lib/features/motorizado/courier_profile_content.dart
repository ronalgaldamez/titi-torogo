import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../cliente/pedido/order_presentation.dart';
import '../shared/client_profile_widgets.dart';
import 'courier_presentation.dart';

Future<bool> showCourierLogout(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OrderPresentation.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      builder: (context) => Theme(
        data: OrderPresentation.theme(context),
        child: ProfileSheet(
          eyebrow: 'TU CUENTA TOROGO',
          title: '¿Nos vemos\nen la próxima',
          punctuation: '?',
          onClose: () => Navigator.pop(context, false),
          children: [
            const Text(
              'Vas a salir de tu cuenta en este teléfono. Para volver, usá tu correo y contraseña.',
              style: TextStyle(
                fontSize: 12,
                height: 1.65,
                color: OrderPresentation.muted,
              ),
            ),
            const SizedBox(height: 28),
            ProfilePrimaryButton(
              label: 'Sí, cerrar sesión',
              icon: Icons.north_east_rounded,
              onPressed: () => Navigator.pop(context, true),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Me quedo aquí',
                style: TextStyle(fontSize: 12, color: OrderPresentation.muted),
              ),
            ),
          ],
        ),
      ),
    ) ??
    false;

class CourierProfileContent extends StatelessWidget {
  const CourierProfileContent({
    required this.user,
    required this.avatar,
    required this.savingAvatar,
    required this.onAvatar,
    required this.onPersonalInfo,
    required this.onLogout,
    super.key,
  });
  final User user;
  final Widget avatar;
  final bool savingAvatar;
  final VoidCallback onAvatar;
  final VoidCallback onPersonalInfo;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 30, 24, 25),
    children: [
      const CourierEyebrow('TU CUENTA, TU CAMINO'),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: user.name.replaceFirst(' ', '\n')),
                  const TextSpan(
                    text: '.',
                    style: TextStyle(color: OrderPresentation.coral),
                  ),
                ],
              ),
              semanticsLabel: user.name,
              style: const TextStyle(
                fontSize: 31,
                height: 1.05,
                letterSpacing: -1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Semantics(
            button: true,
            label: 'Elegir avatar',
            child: InkWell(
              onTap: savingAvatar ? null : onAvatar,
              borderRadius: BorderRadius.circular(23),
              child: SizedBox(
                width: 79,
                height: 82,
                child: Stack(
                  children: [
                    ExcludeSemantics(child: avatar),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: OrderPresentation.coral,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: OrderPresentation.background,
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
      const SizedBox(height: 10),
      const Text(
        'Qué bueno tenerte en la ruta.',
        style: TextStyle(
          fontSize: 12,
          height: 1.65,
          color: OrderPresentation.muted,
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: savingAvatar ? null : onAvatar,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            foregroundColor: OrderPresentation.coral,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                savingAvatar ? 'Guardando…' : 'Elegí tu avatar',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 9),
              const Icon(Icons.north_east_rounded, size: 16),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      const CourierEyebrow('LO TUYO, BIEN GUARDADO'),
      const SizedBox(height: 10),
      _CourierProfileRow(
        icon: Icons.person_outline_rounded,
        title: 'Información personal',
        subtitle: user.email,
        onTap: onPersonalInfo,
      ),
      _CourierProfileRow(
        icon: Icons.tune_rounded,
        title: 'Preferencias',
        subtitle: 'A tu manera',
        soon: true,
        onTap: () => _soon(context),
      ),
      _CourierProfileRow(
        icon: Icons.help_outline_rounded,
        title: 'Ayuda y soporte',
        subtitle: 'Para acompañarte',
        soon: true,
        onTap: () => _soon(context),
      ),
      if (onLogout != null)
        TextButton(
          onPressed: onLogout,
          style: TextButton.styleFrom(
            foregroundColor: OrderPresentation.coral,
            padding: const EdgeInsets.symmetric(vertical: 25),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cerrar sesión',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.north_east_rounded, size: 18),
            ],
          ),
        ),
      const SizedBox(height: 19),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.route_outlined, size: 18, color: OrderPresentation.coral),
          SizedBox(width: 14),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Vos ponés el camino.\n'),
                  TextSpan(
                    text: 'Lo bueno va con vos.',
                    style: TextStyle(
                      color: OrderPresentation.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 11,
                height: 1.65,
                color: OrderPresentation.muted,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  void _soon(BuildContext context) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Próximamente.')));
}

class _CourierProfileRow extends StatelessWidget {
  const _CourierProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.soon = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool soon;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: OrderPresentation.line)),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 23),
        child: Row(
          children: [
            Icon(icon, size: 18, color: OrderPresentation.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: OrderPresentation.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: OrderPresentation.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (soon)
              const SizedBox(
                width: 54,
                child: Text(
                  'EN CAMINO',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 8,
                    color: OrderPresentation.muted,
                    letterSpacing: .5,
                  ),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: OrderPresentation.muted,
              ),
          ],
        ),
      ),
    ),
  );
}

class CourierPersonalInfoSheet extends StatelessWidget {
  const CourierPersonalInfoSheet({required this.user, super.key});
  final User user;
  @override
  Widget build(BuildContext context) => ProfileSheet(
    eyebrow: 'TU CUENTA TOROGO',
    title: 'Lo tuyo',
    onClose: () => Navigator.pop(context),
    children: [
      const Text(
        'Tus datos, en un solo lugar.',
        style: TextStyle(
          fontSize: 12,
          height: 1.65,
          color: OrderPresentation.muted,
        ),
      ),
      const SizedBox(height: 28),
      for (final entry in {
        'NOMBRE': user.name,
        'CORREO ELECTRÓNICO': user.email,
        'ROL': user.roleLabel,
      }.entries)
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.only(bottom: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: OrderPresentation.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CourierEyebrow(entry.key),
              const SizedBox(height: 11),
              SelectableText(
                entry.value,
                style: const TextStyle(
                  fontSize: 14,
                  color: OrderPresentation.ink,
                ),
              ),
            ],
          ),
        ),
      const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: OrderPresentation.muted,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Si necesitás corregir tus datos, contactá al administrador.',
              style: TextStyle(
                fontSize: 11,
                height: 1.65,
                color: OrderPresentation.muted,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 26),
      ProfilePrimaryButton(
        label: 'Volver al perfil',
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}
