import 'package:flutter/material.dart';

import '../cliente/pedido/order_presentation.dart';
import '../shared/client_profile_widgets.dart';

Future<bool> showRestaurantLogout(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OrderPresentation.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      builder: (context) => Theme(
        data: OrderPresentation.theme(context),
        child: RestaurantSheet(
          eyebrow: 'TU CUENTA',
          title: '¿Cerramos\npor aquí',
          punctuation: '?',
          icon: Icons.logout_rounded,
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
            Container(
              margin: const EdgeInsets.symmetric(vertical: 23),
              padding: const EdgeInsets.only(top: 17),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: OrderPresentation.line)),
              ),
              child: const Row(
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
                      'Salir de tu cuenta no cierra tu local ni cambia sus pedidos.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        color: OrderPresentation.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

class RestaurantSheet extends StatelessWidget {
  const RestaurantSheet({
    required this.eyebrow,
    required this.title,
    required this.onClose,
    required this.children,
    this.punctuation = '.',
    this.icon,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String punctuation;
  final IconData? icon;
  final VoidCallback onClose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
    style: const TextStyle(color: OrderPresentation.ink),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          14 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: OrderPresentation.muted.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    eyebrow,
                    style: const TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                      color: OrderPresentation.muted,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Cerrar',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: OrderPresentation.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (icon != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Icon(icon, size: 31, color: OrderPresentation.coral),
              ),
              const SizedBox(height: 19),
            ],
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: title),
                  TextSpan(
                    text: punctuation,
                    style: const TextStyle(color: OrderPresentation.coral),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 31,
                height: 1.12,
                letterSpacing: -.8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    ),
  );
}
