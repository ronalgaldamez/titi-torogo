import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../auth/auth_repository.dart';

class ClientPersonalInfoSheet extends StatefulWidget {
  const ClientPersonalInfoSheet({required this.user, super.key});

  final User user;

  @override
  State<ClientPersonalInfoSheet> createState() =>
      _ClientPersonalInfoSheetState();
}

class _ClientPersonalInfoSheetState extends State<ClientPersonalInfoSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _phone = TextEditingController(text: widget.user.phone ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final storage = AuthStorage();
      final api = await Session(storage).client();
      final user = await AuthRepository(api, storage).updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context, user);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Información personal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Nombre'),
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 255,
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) {
                    return 'Escribí tu nombre.';
                  }
                  if (name.runes.length < 2) {
                    return 'El nombre debe tener al menos 2 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _phone,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  helperText: 'Opcional · El Salvador, 8 dígitos o +503',
                ),
                autofillHints: const [AutofillHints.telephoneNumber],
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                maxLength: 30,
                onFieldSubmitted: (_) => _save(),
                validator: (value) {
                  final phone = (value ?? '').replaceAll(RegExp(r'[\s-]+'), '');
                  if (phone.isNotEmpty &&
                      !RegExp(r'^(?:\+503)?[267][0-9]{7}$').hasMatch(phone)) {
                    return 'Usá 8 dígitos que comiencen con 2, 6 o 7.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                initialValue: widget.user.email,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  helperText: 'El correo no se puede cambiar desde el perfil.',
                  suffixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
