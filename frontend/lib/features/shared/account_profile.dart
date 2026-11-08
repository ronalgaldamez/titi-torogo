import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/session.dart';
import '../motorizado/courier_presentation.dart';
import '../motorizado/courier_profile_content.dart';
import '../../models/user.dart';
import 'client_personal_info_sheet.dart';
import 'client_profile_widgets.dart';
import '../cliente/pedido/order_presentation.dart';

class AccountProfile extends StatefulWidget {
  const AccountProfile({
    required this.onLogout,
    this.courier = false,
    super.key,
  });

  final bool courier;

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
      backgroundColor: OrderPresentation.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Theme(
        data: OrderPresentation.theme(context),
        child: ClientAvatarSheet(
          selected: _avatar,
          avatarBuilder: (index, size) =>
              _profileAvatar(initials, index, size: size),
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

  Widget _profileAvatar(String initials, int index, {double size = 84}) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(
          size == 84
              ? 26
              : size == 75
              ? 23
              : 18,
        ),
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
                        fontSize: size == 84 || size == 75 ? 26 : 20,
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
      );

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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OrderPresentation.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Theme(
        data: OrderPresentation.theme(context),
        child: CourierPersonalInfoSheet(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: OrderPresentation.theme(context),
    child: DefaultTextStyle.merge(
      style: const TextStyle(color: OrderPresentation.ink),
      child: ColoredBox(
        color: OrderPresentation.background,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (widget.courier)
                const CourierBrandHeader()
              else
                const OrderBrandHeader(),
              Expanded(
                child: FutureBuilder<User>(
                  future: _user,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
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
                    if (widget.courier) {
                      return CourierProfileContent(
                        user: user,
                        avatar: _profileAvatar(initials, _avatar, size: 75),
                        savingAvatar: _savingAvatar,
                        onAvatar: () => _chooseAvatar(user, initials),
                        onPersonalInfo: () => _showPersonalInfo(user),
                        onLogout: widget.onLogout,
                      );
                    }
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
  );
}
