import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../core/money.dart';
import '../../../models/menu_category.dart';
import '../../../models/product.dart';
import 'menu_repository.dart';

/// El formulario de un plato: sirve para AGREGAR y para EDITAR.
///
/// Es pantalla completa y no un cuadro chico porque son varios campos mas el
/// teclado: en un modal apretado el teclado tapa el boton de guardar, que es
/// justo el que hay que tocar.
///
/// Al cerrarse devuelve `true` si guardo algo, para que la pantalla del menu
/// sepa que tiene que volver a cargar.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({
    required this.categories,
    this.product,
    this.categoryId,
    this.selectImage,
    super.key,
  });

  /// Las categorias del restaurante, para elegir donde va el plato.
  final List<MenuCategory> categories;

  /// null = plato nuevo.
  final Product? product;

  /// En que categoria esta HOY el plato que se edita.
  ///
  /// Se recibe aparte en vez de leerlo del plato porque la API todavia no
  /// manda `menu_category_id` dentro del producto. La pantalla del menu sabe
  /// en que categoria lo esta mostrando, asi que se lo pasa ella.
  final int? categoryId;
  final Future<XFile?> Function()? selectImage;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  /// El precio se valida como TEXTO, con la misma forma que exige el backend:
  /// digitos y hasta dos decimales.
  ///
  /// Nada de `double.parse`: aceptaria "1.005" y despues la base lo redondearia
  /// sin avisarle a nadie, y el restaurante veria un precio que no escribio.
  static final RegExp _pricePattern = RegExp(r'^\d+(\.\d{1,2})?$');

  final Session _session = Session(AuthStorage());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;

  /// El precio viaja y se edita como String, igual que en toda la app.
  late final TextEditingController _price;

  late final TextEditingController _salePrice;
  bool _offerEnabled = false;
  DateTime? _offerStart;
  DateTime? _offerEnd;
  (Uint8List, String)? _photo;
  bool _picking = false;
  int? _categoryId;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();

    final Product? product = widget.product;

    _name = TextEditingController(text: product?.name ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _price = TextEditingController(
      text: product?.regularPrice ?? product?.price ?? '',
    );
    _salePrice = TextEditingController(text: product?.salePrice ?? '');
    _offerEnabled = product?.offerEnabled ?? false;
    _offerStart = product?.offerStartsAt == null
        ? null
        : _salvadorTime(product!.offerStartsAt!);
    _offerEnd = product?.offerEndsAt == null
        ? null
        : _salvadorTime(product!.offerEndsAt!);
    _price.addListener(_refreshPreview);
    _salePrice.addListener(_refreshPreview);
    _categoryId = widget.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.removeListener(_refreshPreview);
    _salePrice.removeListener(_refreshPreview);
    _price.dispose();
    _salePrice.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final String text = (value ?? '').trim();

    if (text.isEmpty) {
      return 'Poné el nombre del plato.';
    }

    if (text.length > 120) {
      return 'El nombre es demasiado largo.';
    }

    return null;
  }

  String? _validateDescription(String? value) {
    if ((value ?? '').length > 500) {
      return 'La descripción es demasiado larga.';
    }

    return null;
  }

  String? _validatePrice(String? value) {
    final String text = (value ?? '').trim();

    if (text.isEmpty) {
      return 'Poné el precio.';
    }

    if (!_pricePattern.hasMatch(text)) {
      return 'Solo números, con hasta dos decimales (ej. 1.50).';
    }

    return null;
  }

  /// Guarda: crea el plato o lo actualiza, segun de donde se haya entrado.
  Future<void> _save() async {
    if (_saving || _picking) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_offerEnabled &&
        (_offerStart == null ||
            _offerEnd == null ||
            !_offerEnd!.isAfter(_offerStart!))) {
      setState(() => _error = 'La oferta debe terminar después de empezar.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ApiClient api = await _session.client();
      final MenuRepository repository = MenuRepository(api);

      // Vacio = sin descripcion. Se manda null y no "" para que la base
      // guarde NULL, que es lo que significa "no tiene".
      final String description = _description.text.trim();

      if (_isEditing) {
        await repository.updateProduct(
          id: widget.product!.id,
          name: _name.text.trim(),
          price: _price.text.trim(),
          description: description.isEmpty ? null : description,
          categoryId: _categoryId,
          image: _photo,
          offerEnabled: _offerEnabled,
          salePrice: _offerEnabled ? _salePrice.text.trim() : null,
          offerStartsAt: _offerEnabled ? _encodeDate(_offerStart!) : null,
          offerEndsAt: _offerEnabled ? _encodeDate(_offerEnd!) : null,
        );
      } else {
        await repository.createProduct(
          name: _name.text.trim(),
          price: _price.text.trim(),
          description: description.isEmpty ? null : description,
          categoryId: _categoryId,
          image: _photo,
          offerEnabled: _offerEnabled,
          salePrice: _offerEnabled ? _salePrice.text.trim() : null,
          offerStartsAt: _offerEnabled ? _encodeDate(_offerStart!) : null,
          offerEndsAt: _offerEnabled ? _encodeDate(_offerEnd!) : null,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Borra el plato, con confirmacion.
  ///
  /// El texto del cuadro empuja a usar el interruptor cuando lo que pasa es
  /// que hoy no hay: borrar es para cuando el plato sale del menu de verdad.
  Future<void> _delete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('¿Borrar este plato?'),
        content: const Text(
          'Deja de aparecer en tu menú. Si solo se te acabó hoy, apagalo con '
          'el interruptor en vez de borrarlo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ApiClient api = await _session.client();
      await MenuRepository(api).deleteProduct(widget.product!.id);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
        _saving = false;
      });
    }
  }

  void _refreshPreview() => setState(() {});

  // El Salvador no cambia de horario; los selectores editan la hora de pared, no la del teléfono.
  static DateTime _salvadorTime(DateTime instant) {
    final time = instant.toUtc().subtract(const Duration(hours: 6));
    return DateTime(time.year, time.month, time.day, time.hour, time.minute);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
  static String _encodeDate(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}T${_two(date.hour)}:${_two(date.minute)}:00-06:00';
  static String _dateLabel(DateTime? date) => date == null
      ? 'Elegir fecha y hora'
      : '${_two(date.day)}/${_two(date.month)}/${date.year} · ${_two(date.hour)}:${_two(date.minute)}';

  Future<void> _pickDate(bool start) async {
    final initial =
        (start ? _offerStart : _offerEnd) ?? _salvadorTime(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _offerStart = value;
      } else {
        _offerEnd = value;
      }
      _error = null;
    });
  }

  Future<void> _pickPhoto() async {
    if (_saving || _picking) {
      return;
    }
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file =
          await (widget.selectImage?.call() ??
              ImagePicker().pickImage(source: ImageSource.gallery));
      if (file == null) {
        return;
      }
      if (await file.length() > 5 * 1024 * 1024 ||
          !RegExp(
            r'\.(png|jpe?g|webp)$',
            caseSensitive: false,
          ).hasMatch(file.name)) {
        throw ApiException('Elegí una imagen JPG, PNG o WebP de hasta 5 MB.');
      }
      final bytes = await file.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          if (descriptor.width > 6000 || descriptor.height > 6000) {
            throw ApiException(
              'La foto no puede superar 6000 píxeles por lado.',
            );
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
      if (mounted) {
        setState(() => _photo = (bytes, file.name));
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'No pudimos abrir esa foto. Probá otra.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _saving || _picking;
    final normal = Money.toCents(_price.text);
    final sale = Money.toCents(_salePrice.text);
    final discount = normal > 0 && sale < normal
        ? ((normal - sale) * 100 + normal ~/ 2) ~/ normal
        : 0;
    const muted = TextStyle(fontSize: 10, color: AppTheme.discoveryMuted);
    return PopScope(
      canPop: !disabled,
      child: Scaffold(
        backgroundColor: AppTheme.discoveryBackground,
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'toro'),
                                TextSpan(
                                  text: 'go',
                                  style: TextStyle(color: AppTheme.yellow),
                                ),
                                TextSpan(
                                  text: '.',
                                  style: TextStyle(
                                    color: AppTheme.discoveryAccent,
                                  ),
                                ),
                              ],
                            ),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.8,
                              color: AppTheme.discoveryPaper,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'MI NEGOCIO',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.7,
                          color: AppTheme.discoveryMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 22),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TU CARTA, A TU MANERA.',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.7,
                                color: AppTheme.discoveryMuted,
                              ),
                            ),
                            SizedBox(height: 9),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: 'El próximo\nantojo'),
                                  TextSpan(
                                    text: '.',
                                    style: TextStyle(
                                      color: AppTheme.discoveryAccent,
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 34,
                                height: 1.08,
                                letterSpacing: -1.3,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.discoveryPaper,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _isEditing ? 'Editar plato' : 'Agregar plato',
                        style: muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 23),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      height: 208,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _photoPreview(),
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.discoveryBackground.withValues(
                                  alpha: .92,
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.image_outlined,
                                    size: 13,
                                    color: AppTheme.discoveryPaper,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Foto principal',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.discoveryPaper,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: FilledButton.icon(
                              key: const ValueKey('product-pick-photo'),
                              onPressed: disabled ? null : _pickPhoto,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.discoveryPaper,
                                foregroundColor: AppTheme.discoveryBackground,
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                minimumSize: const Size(0, 44),
                              ),
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                size: 18,
                              ),
                              label: Text(
                                _photo == null &&
                                        widget.product?.imageUrl == null
                                    ? 'Agregar foto'
                                    : 'Cambiar foto',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 10,
                    runSpacing: 5,
                    children: [
                      Text('Una buena foto abre el apetito.', style: muted),
                      Text(
                        '1 foto por plato',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.discoveryPaper,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'JPG, PNG o WebP · hasta 5 MB',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.discoveryMuted,
                    ),
                  ),
                  if (_picking || (_saving && _photo != null)) ...[
                    const SizedBox(height: 10),
                    const LinearProgressIndicator(
                      color: AppTheme.discoveryAccent,
                      backgroundColor: Color(0xFF204653),
                      minHeight: 4,
                      semanticsLabel: 'Procesando foto',
                    ),
                  ],
                  const SizedBox(height: 24),
                  _field(
                    _name,
                    'Nombre del plato',
                    _validateName,
                    disabled: disabled,
                  ),
                  const SizedBox(height: 20),
                  _field(
                    _description,
                    'Descripción (opcional)',
                    _validateDescription,
                    maxLines: 2,
                    disabled: disabled,
                  ),
                  const SizedBox(height: 20),
                  _field(
                    _price,
                    'Precio normal · USD',
                    _validatePrice,
                    money: true,
                    disabled: disabled,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¿Dónde va este antojo?',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.discoveryPaper,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in <({int? id, String name})>[
                        for (final category in widget.categories)
                          (id: category.id, name: category.name),
                        (id: null, name: 'Sin categoría'),
                      ])
                        ChoiceChip(
                          label: Text(entry.name),
                          selected: _categoryId == entry.id,
                          onSelected: disabled
                              ? null
                              : (_) => setState(() => _categoryId = entry.id),
                          backgroundColor: AppTheme.discoveryBackground,
                          selectedColor: AppTheme.discoveryAccent,
                          checkmarkColor: AppTheme.discoveryBackground,
                          showCheckmark: false,
                          side: BorderSide(
                            color: _categoryId == entry.id
                                ? AppTheme.discoveryAccent
                                : Colors.white30,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: _categoryId == entry.id
                                ? AppTheme.discoveryBackground
                                : AppTheme.discoveryMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Divider(color: Colors.white24, height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.discount_outlined,
                          size: 23,
                          color: AppTheme.yellow,
                        ),
                        const SizedBox(width: 11),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dale un empujoncito.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.discoveryPaper,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text('Oferta por tiempo limitado', style: muted),
                            ],
                          ),
                        ),
                        Semantics(
                          key: const ValueKey('product-offer-toggle'),
                          label: 'Oferta por tiempo limitado',
                          toggled: _offerEnabled,
                          onTap: disabled
                              ? null
                              : () => setState(() {
                                  _offerEnabled = !_offerEnabled;
                                  _error = null;
                                }),
                          child: GestureDetector(
                            excludeFromSemantics: true,
                            behavior: HitTestBehavior.opaque,
                            onTap: disabled
                                ? null
                                : () => setState(() {
                                    _offerEnabled = !_offerEnabled;
                                    _error = null;
                                  }),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: ExcludeSemantics(
                                child: IgnorePointer(
                                  child: Transform.scale(
                                    scale: .82,
                                    child: Switch(
                                      value: _offerEnabled,
                                      onChanged: disabled
                                          ? null
                                          : (value) => setState(
                                              () => _offerEnabled = value,
                                            ),
                                      activeTrackColor:
                                          AppTheme.discoveryAccent,
                                      activeThumbColor:
                                          AppTheme.discoveryBackground,
                                      inactiveTrackColor: const Color(
                                        0xFF47616C,
                                      ),
                                      inactiveThumbColor:
                                          AppTheme.discoveryPaper,
                                      trackOutlineColor:
                                          const WidgetStatePropertyAll(
                                            Colors.transparent,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_offerEnabled) ...[
                    _field(
                      _salePrice,
                      'Precio de oferta · USD',
                      (value) {
                        final error = _validatePrice(value);
                        if (error != null) {
                          return error;
                        }
                        return Money.toCents(value!) >=
                                Money.toCents(_price.text)
                            ? 'La oferta debe ser menor que el precio normal.'
                            : null;
                      },
                      money: true,
                      disabled: disabled,
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final dates = [
                          _dateButton(
                            'Empieza',
                            _offerStart,
                            () => _pickDate(true),
                            disabled,
                          ),
                          _dateButton(
                            'Termina',
                            _offerEnd,
                            () => _pickDate(false),
                            disabled,
                          ),
                        ];
                        return constraints.maxWidth < 320 ||
                                MediaQuery.textScalerOf(context).scale(1) > 1.2
                            ? Column(
                                children: [
                                  dates[0],
                                  const SizedBox(height: 14),
                                  dates[1],
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: dates[0]),
                                  const SizedBox(width: 14),
                                  Expanded(child: dates[1]),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: AppTheme.discoveryMuted,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Hora de El Salvador',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.discoveryMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 19),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF183B49),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Así se verá el precio',
                                  style: muted,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 10,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '\$${Money.fromCents(normal)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        decoration: TextDecoration.lineThrough,
                                        color: AppTheme.discoveryMuted,
                                      ),
                                    ),
                                    Text(
                                      '\$${Money.fromCents(sale)}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.discoveryAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.yellow,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              discount > 0 ? '−$discount%' : '—',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.discoveryBackground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Al terminar, vuelve automáticamente al precio normal.',
                      style: muted,
                    ),
                    const SizedBox(height: 19),
                  ],
                  const Divider(color: Colors.white24, height: 1),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.discoveryAccent,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 25),
                  FilledButton(
                    onPressed: disabled ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.discoveryAccent,
                      foregroundColor: AppTheme.discoveryBackground,
                      minimumSize: const Size.fromHeight(56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _saving ? 'Guardando…' : 'Guardar cambios',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_saving)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.discoveryBackground,
                            ),
                          )
                        else
                          const Icon(Icons.check_rounded, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: disabled
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Volver sin guardar',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.discoveryMuted,
                          ),
                        ),
                      ),
                      if (_isEditing)
                        TextButton(
                          onPressed: disabled ? null : _delete,
                          child: const Text(
                            'Borrar plato',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.discoveryAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoPreview() {
    const fallback = ColoredBox(
      color: Color(0xFF183B49),
      child: Center(
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: AppTheme.discoveryMuted,
          size: 40,
        ),
      ),
    );
    if (_photo != null) {
      return Image.memory(
        _photo!.$1,
        fit: BoxFit.cover,
        alignment: const Alignment(0, .34),
        errorBuilder: (_, error, stack) => fallback,
      );
    }
    final url = widget.product?.imageUrl;
    return url == null
        ? fallback
        : Image.network(
            url,
            fit: BoxFit.cover,
            alignment: const Alignment(0, .34),
            errorBuilder: (_, error, stack) => fallback,
          );
  }

  Widget _dateButton(
    String label,
    DateTime? date,
    VoidCallback onTap,
    bool disabled,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppTheme.discoveryPaper),
      ),
      TextButton(
        onPressed: disabled ? null : onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          minimumSize: const Size.fromHeight(44),
          alignment: Alignment.centerLeft,
          shape: const RoundedRectangleBorder(),
        ),
        child: Text(
          _dateLabel(date),
          style: const TextStyle(fontSize: 12, color: AppTheme.discoveryPaper),
        ),
      ),
      const Divider(height: 1, color: Colors.white30),
    ],
  );

  Widget _field(
    TextEditingController controller,
    String label,
    FormFieldValidator<String> validator, {
    int maxLines = 1,
    bool money = false,
    required bool disabled,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppTheme.discoveryPaper),
      ),
      Semantics(
        label: label,
        child: TextFormField(
          controller: controller,
          enabled: !disabled,
          validator: validator,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 16,
            fontWeight: money ? FontWeight.w600 : FontWeight.w400,
            color: AppTheme.discoveryPaper,
          ),
          keyboardType: money
              ? const TextInputType.numberWithOptions(decimal: true)
              : maxLines > 1
              ? TextInputType.multiline
              : TextInputType.text,
          inputFormatters: money
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
            prefixText: money ? '\$  ' : null,
            prefixStyle: const TextStyle(
              color: AppTheme.discoveryAccent,
              fontSize: 18,
            ),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.discoveryAccent),
            ),
            errorStyle: const TextStyle(color: AppTheme.discoveryAccent),
            errorMaxLines: 3,
          ),
        ),
      ),
    ],
  );
}
