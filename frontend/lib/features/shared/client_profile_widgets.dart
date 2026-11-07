import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../cliente/pedido/order_presentation.dart';

class ClientProfileContent extends StatelessWidget {
  const ClientProfileContent({
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
    padding: const EdgeInsets.fromLTRB(24, 32, 24, 22),
    children: [
      const _Eyebrow('TU CUENTA, A TU MANERA'),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: user.name.replaceFirst(' ', '\n')),
                      const TextSpan(
                        text: '.',
                        style: TextStyle(color: OrderPresentation.coral),
                      ),
                    ],
                  ),
                  key: const ValueKey('client-profile-name'),
                  style: const TextStyle(
                    fontSize: 38,
                    height: 1.05,
                    letterSpacing: -1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Qué bueno tenerte aquí.',
                  style: TextStyle(
                    fontSize: 12,
                    color: OrderPresentation.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            label: 'Cambiar avatar',
            button: true,
            child: InkWell(
              onTap: savingAvatar ? null : onAvatar,
              borderRadius: BorderRadius.circular(26),
              child: SizedBox(
                width: 88,
                height: 90,
                child: Stack(
                  children: [
                    ExcludeSemantics(child: avatar),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 31,
                        height: 31,
                        decoration: BoxDecoration(
                          color: OrderPresentation.coral,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: OrderPresentation.background,
                            width: 4,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 12,
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
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: savingAvatar ? null : onAvatar,
          style: TextButton.styleFrom(
            foregroundColor: OrderPresentation.coral,
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 44),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                savingAvatar ? 'Guardando…' : 'Elegí tu avatar',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 9),
              const Icon(Icons.north_east_rounded, size: 14),
            ],
          ),
        ),
      ),
      const SizedBox(height: 30),
      const _Eyebrow('LO TUYO, BIEN GUARDADO'),
      _ProfileRow(
        icon: Icons.person_outline_rounded,
        title: 'Información personal',
        subtitle: user.email,
        onTap: onPersonalInfo,
      ),
      _ProfileRow(
        icon: Icons.tune_rounded,
        title: 'Preferencias',
        subtitle: 'Próximamente',
        comingSoon: true,
        onTap: () => _soon(context, 'Preferencias'),
      ),
      _ProfileRow(
        icon: Icons.help_outline_rounded,
        title: 'Ayuda y soporte',
        subtitle: 'Próximamente',
        comingSoon: true,
        onTap: () => _soon(context, 'Ayuda y soporte'),
      ),
      if (onLogout != null) ...[
        const SizedBox(height: 10),
        TextButton(
          onPressed: onLogout,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 23),
            foregroundColor: OrderPresentation.coral,
          ),
          child: const Row(
            children: [
              Icon(Icons.logout_rounded, size: 18),
              SizedBox(width: 13),
              Expanded(
                child: Text('Cerrar sesión', style: TextStyle(fontSize: 12)),
              ),
              Icon(Icons.north_east_rounded, size: 16),
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
      const Row(
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 18,
            color: OrderPresentation.coral,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Menos vueltas.\n',
                    style: TextStyle(color: OrderPresentation.muted),
                  ),
                  TextSpan(text: 'Más de lo que te gusta.'),
                ],
              ),
              style: TextStyle(fontSize: 11, height: 1.7),
            ),
          ),
        ],
      ),
    ],
  );

  void _soon(BuildContext context, String feature) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$feature · Próximamente')));
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.comingSoon = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool comingSoon;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 88),
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OrderPresentation.line)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: OrderPresentation.coral),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
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
          if (comingSoon)
            const SizedBox(
              width: 67,
              child: Text(
                'EN CAMINO',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 1,
                  height: 1.6,
                  color: OrderPresentation.muted,
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
  );
}

class ProfileSheet extends StatelessWidget {
  const ProfileSheet({
    required this.title,
    required this.onClose,
    required this.children,
    this.punctuation = '.',
    super.key,
  });
  final String title;
  final String punctuation;
  final VoidCallback? onClose;
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
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 37,
                height: 4,
                decoration: BoxDecoration(
                  color: OrderPresentation.muted.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Eyebrow('TU PERFIL TOROGO'),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: title),
                            TextSpan(
                              text: punctuation,
                              style: const TextStyle(
                                color: OrderPresentation.coral,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 27,
                          height: 1.15,
                          letterSpacing: -.9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 26),
            ...children,
          ],
        ),
      ),
    ),
  );
}

class ProfilePrimaryButton extends StatelessWidget {
  const ProfilePrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon = Icons.check_rounded,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: OrderPresentation.coral,
      foregroundColor: OrderPresentation.background,
      minimumSize: const Size.fromHeight(52),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: OrderPresentation.background,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: OrderPresentation.ink),
        ),
      ],
    ),
  );
}

class ClientAvatarSheet extends StatefulWidget {
  const ClientAvatarSheet({
    required this.selected,
    required this.avatarBuilder,
    super.key,
  });
  final int selected;
  final Widget Function(int index, double size) avatarBuilder;

  @override
  State<ClientAvatarSheet> createState() => _ClientAvatarSheetState();
}

class _ClientAvatarSheetState extends State<ClientAvatarSheet> {
  late int _selected = widget.selected;

  @override
  Widget build(BuildContext context) => ProfileSheet(
    title: 'Ponele tu toque',
    onClose: () => Navigator.pop(context),
    children: [
      const Text(
        'Elegí cómo querés aparecer.\nTu avatar se guarda en este dispositivo.',
        style: TextStyle(
          fontSize: 12,
          height: 1.7,
          color: OrderPresentation.muted,
        ),
      ),
      const SizedBox(height: 22),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 20) / 3;
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: List.generate(
              7,
              (index) => SizedBox(
                width: width,
                child: Semantics(
                  selected: index == _selected,
                  child: OutlinedButton(
                    key: ValueKey('client-avatar-$index'),
                    onPressed: () => setState(() => _selected = index),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: OrderPresentation.background,
                      foregroundColor: OrderPresentation.ink,
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                        horizontal: 4,
                      ),
                      minimumSize: const Size(48, 104),
                      side: BorderSide(
                        color: index == _selected
                            ? OrderPresentation.coral
                            : Colors.transparent,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: widget.avatarBuilder(index, 52),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                index == 0 ? 'Iniciales' : 'Avatar $index',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: index == _selected
                                      ? OrderPresentation.ink
                                      : OrderPresentation.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (index == _selected)
                          const Positioned(
                            top: 0,
                            right: 1,
                            child: Icon(
                              Icons.check_rounded,
                              size: 13,
                              color: OrderPresentation.coral,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 29),
      ProfilePrimaryButton(
        label: 'Usar este avatar',
        icon: Icons.north_east_rounded,
        onPressed: () => Navigator.pop(context, _selected),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text(
          'Cancelar',
          style: TextStyle(fontSize: 12, color: OrderPresentation.muted),
        ),
      ),
    ],
  );
}

class ClientLogoutSheet extends StatelessWidget {
  const ClientLogoutSheet({super.key});

  @override
  Widget build(BuildContext context) => ProfileSheet(
    title: '¿Nos vemos luego',
    punctuation: '?',
    onClose: () => Navigator.pop(context, false),
    children: [
      const Text(
        'Vas a salir de tu cuenta en este dispositivo. Tus pedidos y tus datos quedan guardados.',
        style: TextStyle(
          fontSize: 13,
          height: 1.8,
          color: OrderPresentation.muted,
        ),
      ),
      const SizedBox(height: 29),
      ProfilePrimaryButton(
        label: 'Sí, cerrar sesión',
        icon: Icons.logout_rounded,
        onPressed: () => Navigator.pop(context, true),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text(
          'Me quedo por aquí',
          style: TextStyle(fontSize: 12, color: OrderPresentation.muted),
        ),
      ),
    ],
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 9,
      letterSpacing: 1.6,
      height: 1.7,
      color: OrderPresentation.muted,
      fontWeight: FontWeight.w700,
    ),
  );
}
