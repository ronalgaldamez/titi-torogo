import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import 'client_personal_info_sheet.dart';
import 'client_profile_widgets.dart';
import '../cliente/pedido/order_presentation.dart';

class AccountProfile extends StatefulWidget {
  const AccountProfile({
    required this.onLogout,
    this.clientDesign = true,
    super.key,
  });

  final bool clientDesign;

  final VoidCallback? onLogout;

  @override
  State<AccountProfile> createState() => _AccountProfileState();
}

class _AccountProfileState extends State<AccountProfile> {
  late Future<User> _user;
  int _avatar = 0;
  bool _savingAvatar = false;

  @override
  void initState() {
    super.initState();
    _user = _load();
  }

  Future<User> _load() async {
    final api = await Session(AuthStorage()).client();
    final user = User.fromJson(await api.get('/me'));
    final preferences = await SharedPreferences.getInstance();
    final saved =
        preferences.getInt('torogo_${user.role}_avatar_${user.id}') ?? 0;
    _avatar = saved >= 0 && saved <= 6 ? saved : 0;
    return user;
  }

  Future<void> _chooseAvatar(User user, String initials) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: widget.clientDesign ? OrderPresentation.surface : null,
      showDragHandle: !widget.clientDesign,
      shape: widget.clientDesign
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            )
          : null,
      builder: (sheetContext) => widget.clientDesign
          ? Theme(
              data: OrderPresentation.theme(context),
              child: ClientAvatarSheet(
                selected: _avatar,
                avatarBuilder: (index, size) =>
                    _profileAvatar(initials, index, size: size),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Elegí tu avatar',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text('Se guarda en este dispositivo.'),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: List.generate(
                        7,
                        (index) => SizedBox(
                          width: 96,
                          child: Semantics(
                            selected: index == _avatar,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                side: BorderSide(
                                  color: index == _avatar
                                      ? AppTheme.tealDeep
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                ),
                                backgroundColor: index == _avatar
                                    ? AppTheme.tealSoft
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.image,
                                  ),
                                ),
                              ),
                              onPressed: () =>
                                  Navigator.pop(sheetContext, index),
                              child: Column(
                                children: <Widget>[
                                  ExcludeSemantics(
                                    child: _profileAvatar(initials, index),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(
                                    index == 0 ? 'Iniciales' : 'Avatar $index',
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(
                                    height: 16,
                                    child: index == _avatar
                                        ? const ExcludeSemantics(
                                            child: Icon(
                                              Icons.check_rounded,
                                              size: 16,
                                            ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            ),
    );
    if (!mounted || selected == null || selected == _avatar) {
      return;
    }
    setState(() {
      _savingAvatar = true;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setInt(
        'torogo_${user.role}_avatar_${user.id}',
        selected,
      );
      if (!saved) {
        throw StateError('Avatar no guardado');
      }
      if (mounted) {
        setState(() {
          _avatar = selected;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tu avatar se actualizó.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos guardar tu avatar. Probá de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingAvatar = false;
        });
      }
    }
  }

  Widget _legacyAvatar(String initials, int index) => ClipOval(
    child: ColoredBox(
      color: AppTheme.tealSoft,
      child: SizedBox(
        width: 64,
        height: 64,
        child: index == 0
            ? Center(
                child: Text(
                  initials,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.tealDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : Image.asset(
                'assets/avatars/avatar_$index.png',
                fit: BoxFit.cover,
              ),
      ),
    ),
  );

  Widget _profileAvatar(String initials, int index, {double size = 84}) =>
      widget.clientDesign
      ? ClipRRect(
          borderRadius: BorderRadius.circular(size == 84 ? 26 : 18),
          child: ColoredBox(
            color: OrderPresentation.ink,
            child: SizedBox(
              width: size,
              height: size,
              child: index == 0
                  ? Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: OrderPresentation.background,
                          fontSize: size == 84 ? 26 : 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                    )
                  : Image.asset(
                      'assets/avatars/avatar_$index.png',
                      fit: BoxFit.cover,
                    ),
            ),
          ),
        )
      : _legacyAvatar(initials, index);

  Future<void> _showPersonalInfo(User user) async {
    if (user.role == 'client') {
      final updated = await showModalBottomSheet<User>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: OrderPresentation.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => Theme(
          data: OrderPresentation.theme(context),
          child: ClientPersonalInfoSheet(user: user),
        ),
      );
      if (mounted && updated != null) {
        setState(() {
          _user = Future.value(updated);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tus datos se guardaron.')),
        );
      }
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Información personal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              for (final entry in <String, String>{
                'Nombre': user.name,
                'Correo electrónico': user.email,
                'Rol': user.roleLabel,
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SelectableText(entry.value),
                    ],
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.clientDesign
      ? Theme(
          data: OrderPresentation.theme(context),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: OrderPresentation.ink),
            child: ColoredBox(
              color: OrderPresentation.background,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    const OrderBrandHeader(),
                    Expanded(
                      child: FutureBuilder<User>(
                        future: _user,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            final error = snapshot.error;
                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      error is ApiException
                                          ? error.message
                                          : 'No pudimos cargar tu perfil.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      final pending = _load();
                                      setState(() {
                                        _user = pending;
                                      });
                                    },
                                    child: const Text('Reintentar'),
                                  ),
                                  if (widget.onLogout != null)
                                    TextButton(
                                      onPressed: widget.onLogout,
                                      child: const Text('Cerrar sesión'),
                                    ),
                                ],
                              ),
                            );
                          }
                          final user = snapshot.data!;
                          final names = user.name
                              .trim()
                              .split(RegExp(r'\s+'))
                              .where((name) => name.isNotEmpty);
                          final initials = names.isEmpty
                              ? '?'
                              : names
                                    .take(2)
                                    .map((name) => name.characters.first)
                                    .join()
                                    .toUpperCase();
                          return ClientProfileContent(
                            user: user,
                            avatar: _profileAvatar(initials, _avatar),
                            savingAvatar: _savingAvatar,
                            onAvatar: () => _chooseAvatar(user, initials),
                            onPersonalInfo: () => _showPersonalInfo(user),
                            onLogout: widget.onLogout,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        )
      : _legacyBuild(context);

  Widget _legacyBuild(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          FutureBuilder<User>(
            future: _user,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return Column(
                  children: <Widget>[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error is ApiException
                            ? error.message
                            : 'No pudimos cargar tu perfil.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final pendingUser = _load();
                        setState(() {
                          _user = pendingUser;
                        });
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              final user = snapshot.data!;
              final names = user.name
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((name) => name.isNotEmpty)
                  .toList();
              final initials = names.isEmpty
                  ? '?'
                  : names
                        .take(2)
                        .map((name) => name.characters.first)
                        .join()
                        .toUpperCase();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ExcludeSemantics(
                        child: _profileAvatar(initials, _avatar),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              user.name,
                              style: text.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              user.roleLabel,
                              style: text.bodyMedium?.copyWith(
                                color: AppTheme.tealDeep,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _savingAvatar
                          ? null
                          : () => _chooseAvatar(user, initials),
                      icon: const Icon(Icons.face_outlined),
                      label: Text(
                        _savingAvatar ? 'Guardando…' : 'Cambiar avatar',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.image),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Mi cuenta',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_outline_rounded),
                            title: const Text('Información personal'),
                            subtitle: Text(user.email),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _showPersonalInfo(user),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.image),
                    child: const Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: <Widget>[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.tune_rounded),
                            title: Text('Preferencias'),
                            subtitle: Text('Próximamente'),
                          ),
                          Divider(height: AppSpacing.md),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.help_outline_rounded),
                            title: Text('Ayuda y soporte'),
                            subtitle: Text('Próximamente'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          if (widget.onLogout != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded, color: AppTheme.navy),
              title: const Text('Cerrar sesión'),
              onTap: widget.onLogout,
            ),
        ],
      ),
    );
  }
}
