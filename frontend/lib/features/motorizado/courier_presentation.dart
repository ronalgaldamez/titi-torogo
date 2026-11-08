import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cliente/pedido/order_presentation.dart';

class CourierBrandHeader extends StatelessWidget {
  const CourierBrandHeader({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.only(top: 24, bottom: 25),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OrderPresentation.line)),
      ),
      child: const Row(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'toro'),
                TextSpan(
                  text: 'go',
                  style: TextStyle(color: OrderPresentation.yellow),
                ),
                TextSpan(
                  text: '.',
                  style: TextStyle(color: OrderPresentation.coral),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              color: OrderPresentation.ink,
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: Text(
              'EN TU RUTA',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.6,
                color: OrderPresentation.muted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class CourierEyebrow extends StatelessWidget {
  const CourierEyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.6,
      color: OrderPresentation.muted,
    ),
  );
}

class CourierHeading extends StatelessWidget {
  const CourierHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CourierEyebrow(eyebrow),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: title),
                  const TextSpan(
                    text: '.',
                    style: TextStyle(color: OrderPresentation.coral),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 34,
                height: 1.05,
                letterSpacing: -1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                height: 1.65,
                color: OrderPresentation.muted,
              ),
            ),
          ],
        ),
      ),
      if (action != null) ...[const SizedBox(width: 12), action!],
    ],
  );
}

class CourierEarnings extends StatelessWidget {
  const CourierEarnings({
    required this.eyebrow,
    required this.earnings,
    required this.deliveries,
    super.key,
  });
  final String eyebrow;
  final String earnings;
  final int deliveries;
  @override
  Widget build(BuildContext context) {
    final parts = earnings.split('.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CourierEyebrow(eyebrow),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '\$${parts.first}'),
                if (parts.length == 2)
                  TextSpan(
                    text: '.${parts.last}',
                    style: const TextStyle(
                      fontSize: 40,
                      color: OrderPresentation.coral,
                      letterSpacing: -2,
                    ),
                  ),
              ],
            ),
            style: const TextStyle(
              fontSize: 64,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -3,
              color: OrderPresentation.ink,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: OrderPresentation.mint,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                deliveries == 1
                    ? '1 entrega completada'
                    : '$deliveries entregas completadas',
                style: const TextStyle(
                  fontSize: 12,
                  color: OrderPresentation.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Entregas y propinas, no el efectivo cobrado.',
          style: TextStyle(
            fontSize: 11,
            height: 1.65,
            color: OrderPresentation.muted,
          ),
        ),
      ],
    );
  }
}

class CourierEmpty extends StatelessWidget {
  const CourierEmpty({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: OrderPresentation.yellow, size: 31),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            height: 1.12,
            letterSpacing: -.8,
            fontWeight: FontWeight.w800,
            color: OrderPresentation.ink,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          message,
          style: const TextStyle(
            fontSize: 11,
            height: 1.65,
            color: OrderPresentation.muted,
          ),
        ),
      ],
    ),
  );
}
