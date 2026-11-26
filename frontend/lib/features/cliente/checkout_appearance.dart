import 'package:flutter/material.dart';

import '../../core/theme.dart';

const flowSheet = Color(0xFF163744);
const flowField = Color(0xFF0D2734);
const flowRule = Color(0xFF395361);
const flowMint = Color(0xFF91D9C9);

ThemeData checkoutTheme(BuildContext context) {
  final theme = Theme.of(context);
  return theme.copyWith(
    colorScheme: const ColorScheme.dark(
      primary: flowMint,
      onPrimary: AppTheme.discoveryBackground,
      surface: flowField,
      onSurface: AppTheme.discoveryPaper,
      onSurfaceVariant: AppTheme.discoveryMuted,
      outline: flowRule,
      outlineVariant: flowRule,
      error: AppTheme.discoveryAccent,
    ),
    textTheme: theme.textTheme.apply(
      bodyColor: AppTheme.discoveryPaper,
      displayColor: AppTheme.discoveryPaper,
    ),
    dividerTheme: const DividerThemeData(color: flowRule),
    iconTheme: const IconThemeData(color: AppTheme.discoveryPaper),
  );
}

AppBar checkoutAppBar({bool back = true, List<Widget>? actions}) => AppBar(
  automaticallyImplyLeading: back,
  backgroundColor: AppTheme.discoveryBackground,
  foregroundColor: AppTheme.discoveryPaper,
  surfaceTintColor: Colors.transparent,
  centerTitle: true,
  title: const Text.rich(
    TextSpan(
      children: [
        TextSpan(text: 'toro'),
        TextSpan(
          text: 'go',
          style: TextStyle(color: AppTheme.yellow),
        ),
        TextSpan(
          text: '.',
          style: TextStyle(color: AppTheme.discoveryAccent),
        ),
      ],
    ),
    semanticsLabel: 'ToroGo',
    style: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w900,
      letterSpacing: -1.8,
    ),
  ),
  actions: actions,
);

class CheckoutHeading extends StatelessWidget {
  const CheckoutHeading(this.title, {this.caption, super.key});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (caption case final caption?) ...[
        Text(
          caption.toUpperCase(),
          style: const TextStyle(
            color: AppTheme.discoveryMuted,
            fontSize: 11,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
      ],
      Text(
        title,
        style: const TextStyle(
          color: AppTheme.discoveryPaper,
          fontSize: 34,
          height: 1.05,
          letterSpacing: -1.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class CheckoutAction extends StatelessWidget {
  const CheckoutAction(
    this.label, {
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: AppTheme.discoveryAccent,
      foregroundColor: AppTheme.discoveryBackground,
      minimumSize: const Size.fromHeight(51),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    child: loading
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(icon, size: 20),
            ],
          ),
  );
}

class CheckoutThumbnail extends StatelessWidget {
  const CheckoutThumbnail(this.url, {super.key});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 54.0;
    final url = this.url;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    const placeholder = ColoredBox(
      color: flowSheet,
      child: Center(
        child: Icon(Icons.restaurant_rounded, color: AppTheme.discoveryMuted),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: size,
        child: url == null || url.isEmpty
            ? placeholder
            : Image(
                image: ResizeImage(
                  NetworkImage(url),
                  width: pixels,
                  height: pixels,
                  policy: ResizeImagePolicy.fit,
                ),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
