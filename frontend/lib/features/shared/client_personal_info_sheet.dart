import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/session.dart';
import '../cliente/pedido/order_presentation.dart';
import 'client_profile_widgets.dart';
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
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(
        color: OrderPresentation.muted,
        fontSize: 9,
        letterSpacing: 1.3,
        fontWeight: FontWeight.w700,
      ),
      helperStyle: const TextStyle(
        color: OrderPresentation.muted,
        fontSize: 11,
        height: 1.6,
      ),
      helperMaxLines: 3,
      errorMaxLines: 3,
      counterText: '',
      contentPadding: const EdgeInsets.only(top: 10, bottom: 14),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: OrderPresentation.muted.withValues(alpha: .47),
        ),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: OrderPresentation.coral),
      ),
      disabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: OrderPresentation.line),
      ),
    );
    return PopScope(
      canPop: !_saving,
      child: Form(
        key: _form,
        child: ProfileSheet(
          title: 'Lo tuyo',
          onClose: _saving ? null : () => Navigator.pop(context),
          children: [
            const SizedBox(height: 6),
            TextFormField(
              controller: _name,
              enabled: !_saving,
              style: const TextStyle(
                fontSize: 16,
                color: OrderPresentation.ink,
              ),
              decoration: decoration.copyWith(labelText: 'NOMBRE'),
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
            const SizedBox(height: 23),
            TextFormField(
              controller: _phone,
              enabled: !_saving,
              style: const TextStyle(
                fontSize: 16,
                color: OrderPresentation.ink,
              ),
              decoration: decoration.copyWith(
                labelText: 'TELÉFONO · OPCIONAL',
                hintText: 'Ej. 7123 4567',
                hintStyle: const TextStyle(
                  color: OrderPresentation.muted,
                  fontSize: 16,
                ),
                helperText: 'El Salvador · 8 dígitos o +503.',
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
            const SizedBox(height: 23),
            TextFormField(
              initialValue: widget.user.email,
              readOnly: true,
              style: const TextStyle(
                fontSize: 13,
                color: OrderPresentation.muted,
              ),
              decoration: decoration.copyWith(
                labelText: 'CORREO ELECTRÓNICO',
                helperText: 'El correo no se puede cambiar desde el perfil.',
                suffixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: OrderPresentation.muted,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: OrderPresentation.coral,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 29),
            ProfilePrimaryButton(
              label: _saving ? 'Guardando…' : 'Guardar cambios',
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text(
                'Volver al perfil',
                style: TextStyle(fontSize: 12, color: OrderPresentation.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
