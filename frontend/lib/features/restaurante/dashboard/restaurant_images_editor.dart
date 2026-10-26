import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/restaurant.dart';

class RestaurantImagesEditor extends StatefulWidget {
  const RestaurantImagesEditor({
    required this.restaurant,
    required this.disabled,
    required this.onSaved,
    required this.onSaving,
    this.selectImage,
    super.key,
  });

  final Restaurant restaurant;
  final bool disabled;
  final ValueChanged<Restaurant> onSaved;
  final ValueChanged<bool> onSaving;
  final Future<XFile?> Function()? selectImage;

  @override
  State<RestaurantImagesEditor> createState() => _RestaurantImagesEditorState();
}

class _RestaurantImagesEditorState extends State<RestaurantImagesEditor> {
  static const _coverTitleStyle = TextStyle(
    fontSize: 21,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: AppTheme.discoveryPaper,
  );
  static const _coverSubtitleStyle = TextStyle(
    fontSize: 11,
    color: AppTheme.discoveryMuted,
  );
  final _session = Session(AuthStorage());
  final _selected = <String, (Uint8List, String)>{};
  bool _picking = false;
  bool _saving = false;

  Future<void> _pick(String slot) async {
    if (widget.disabled || _picking || _saving) {
      return;
    }
    setState(() => _picking = true);
    try {
      final file =
          await (widget.selectImage?.call() ??
              ImagePicker().pickImage(source: ImageSource.gallery));
      if (file == null) {
        return;
      }
      if (await file.length() > 5 * 1024 * 1024) {
        throw ApiException('Cada imagen puede pesar hasta 5 MB.');
      }
      if (!RegExp(
        r'\.(png|jpe?g|webp)$',
        caseSensitive: false,
      ).hasMatch(file.name)) {
        throw ApiException('Elegí una imagen PNG, JPG o WebP.');
      }
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() => _selected[slot] = (bytes, file.name));
      }
    } catch (error) {
      if (mounted) {
        _notice(
          error is ApiException
              ? error.message
              : 'No pudimos abrir la imagen. Intentá de nuevo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  void _notice(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    if (_selected.isEmpty || widget.disabled || _saving || _picking) {
      return;
    }
    setState(() => _saving = true);
    widget.onSaving(true);
    try {
      final api = await _session.client();
      final response = await api.upload(
        '/restaurant/images',
        files: [
          for (final entry in _selected.entries)
            http.MultipartFile.fromBytes(
              entry.key,
              entry.value.$1,
              filename: entry.value.$2,
            ),
        ],
      );
      final restaurant = Restaurant.fromJson(
        response['restaurant'] as Map<String, dynamic>,
      );
      if (!mounted) {
        return;
      }
      final message = _selected.length == 2
          ? 'Logo y portada actualizados.'
          : _selected.containsKey('logo')
          ? 'Logo actualizado.'
          : 'Portada actualizada.';
      setState(() => _selected.clear());
      widget.onSaved(restaurant);
      _notice(message);
    } catch (error) {
      if (mounted) {
        _notice(
          error is ApiException
              ? error.message
              : 'No pudimos guardar las imágenes. Intentá de nuevo.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        widget.onSaving(false);
      }
    }
  }

  Widget _image(String slot, String? url, BoxFit fit, Widget fallback) {
    final bytes = _selected[slot]?.$1;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, error, stack) => fallback,
      );
    }
    if (url != null) {
      return Image.network(
        url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, error, stack) => fallback,
      );
    }
    return fallback;
  }

  Widget _visuals(bool disabled) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double textHeight(String value, TextStyle style) {
          final painter = TextPainter(
            text: TextSpan(
              text: value,
              style: DefaultTextStyle.of(context).style.merge(style),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth - 48);
          final height = painter.height;
          painter.dispose();
          return height;
        }

        // La portada crece con las líneas reales, incluyendo fuentes grandes y pantallas angostas.
        final coverHeight = math.max(
          190.0,
          textHeight('La primera impresión\nde tu cocina.', _coverTitleStyle) +
              textHeight('Agregá una foto de portada.', _coverSubtitleStyle) +
              106,
        );
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: coverHeight,
              child: SizedBox(
                key: const ValueKey('local-cover-frame'),
                height: coverHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(1.2, -0.6),
                          radius: 1.4,
                          colors: [Color(0xFF40605C), Color(0xFF1C414F)],
                        ),
                      ),
                      child: _image(
                        'cover',
                        widget.restaurant.coverUrl,
                        BoxFit.cover,
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 20, 24, 55),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: AppTheme.yellow,
                                size: 18,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'La primera impresión\nde tu cocina.',
                                style: _coverTitleStyle,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Agregá una foto de portada.',
                                style: _coverSubtitleStyle,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 14,
                      child: FilledButton.icon(
                        key: const ValueKey('pick-cover'),
                        onPressed: disabled ? null : () => _pick('cover'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.discoveryPaper,
                          foregroundColor: AppTheme.discoveryBackground,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 40),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined, size: 14),
                        label: Text(
                          widget.restaurant.coverUrl == null &&
                                  !_selected.containsKey('cover')
                              ? 'Agregar portada'
                              : 'Cambiar portada',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, coverHeight - 24, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    key: const ValueKey('local-logo-frame'),
                    width: 84,
                    height: 84,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.discoveryBackground,
                      borderRadius: BorderRadius.circular(23),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: ColoredBox(
                              color: Colors.white,
                              child: _image(
                                'logo',
                                widget.restaurant.logoUrl,
                                BoxFit.contain,
                                Center(
                                  child: Text(
                                    widget.restaurant.name.trim().isEmpty
                                        ? 'L'
                                        : widget.restaurant.name
                                              .trim()
                                              .characters
                                              .first
                                              .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.discoveryBackground,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              key: const ValueKey('pick-logo'),
                              borderRadius: BorderRadius.circular(18),
                              onTap: disabled ? null : () => _pick('logo'),
                              child: Semantics(
                                label: 'Seleccionar logo',
                                button: true,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: -3,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppTheme.discoveryAccent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.discoveryBackground,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 13,
                                color: AppTheme.discoveryBackground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 35),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tu sello.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.restaurant.logoUrl == null &&
                                    !_selected.containsKey('logo')
                                ? 'Subí el logo de ${widget.restaurant.name}.'
                                : 'Tocá el logo para cambiarlo.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.discoveryMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.disabled || _saving || _picking;
    final name = widget.restaurant.name.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _visuals(disabled),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 21),
              const Text(
                'TU NEGOCIO, A TU MANERA.',
                style: TextStyle(
                  color: AppTheme.discoveryMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 9),
              Text.rich(
                TextSpan(
                  text: name,
                  children: [
                    if (!name.endsWith('.'))
                      const TextSpan(
                        text: '.',
                        style: TextStyle(color: AppTheme.discoveryAccent),
                      ),
                  ],
                ),
                key: const ValueKey('local-business-name'),
                semanticsLabel: name,
                style: TextStyle(
                  fontSize: MediaQuery.sizeOf(context).width <= 360 ? 44 : 51,
                  height: 1.15,
                  letterSpacing: -2,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.discoveryPaper,
                ),
              ),
              if (widget.restaurant.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    widget.restaurant.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.discoveryMuted,
                    ),
                  ),
                ),
              ],
              if (_selected.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Color(0x26FFFFFF)),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selected.length == 2
                                ? 'Logo y portada listos'
                                : _selected.containsKey('logo')
                                ? 'Logo listo'
                                : 'Portada lista',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.discoveryPaper,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _saving
                                ? 'Guardando imagen…'
                                : 'Sin guardar todavía',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.discoveryMuted,
                            ),
                          ),
                        ],
                      );
                      final controls = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: const ValueKey('discard-restaurant-images'),
                            tooltip: 'Descartar selección',
                            onPressed: disabled
                                ? null
                                : () => setState(() => _selected.clear()),
                            color: AppTheme.discoveryMuted,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 44,
                            ),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.close, size: 17),
                          ),
                          const SizedBox(width: 4),
                          FilledButton.icon(
                            key: const ValueKey('save-restaurant-images'),
                            onPressed: disabled ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.discoveryAccent,
                              foregroundColor: AppTheme.discoveryBackground,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 10,
                              ),
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: Text(_saving ? 'Guardando' : 'Guardar'),
                          ),
                        ],
                      );
                      if (constraints.maxWidth < 250 ||
                          MediaQuery.textScalerOf(context).scale(12) > 18) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            details,
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: controls,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 10),
                          controls,
                        ],
                      );
                    },
                  ),
                ),
              ],
              if (_saving || _picking) const LinearProgressIndicator(),
              const SizedBox(height: 13),
              const Text(
                'PNG, JPG o WebP · hasta 5 MB por imagen.',
                style: TextStyle(fontSize: 10, color: AppTheme.discoveryMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
