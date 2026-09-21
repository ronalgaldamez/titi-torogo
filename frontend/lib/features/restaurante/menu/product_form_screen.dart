import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
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
    _price = TextEditingController(text: product?.price ?? '');
    _categoryId = widget.categoryId;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
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
    if (!(_formKey.currentState?.validate() ?? false)) {
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
        );
      } else {
        await repository.createProduct(
          name: _name.text.trim(),
          price: _price.text.trim(),
          description: description.isEmpty ? null : description,
          categoryId: _categoryId,
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

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEditing ? 'Editar plato' : 'Nuevo plato',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        actions: <Widget>[
          if (_isEditing)
            IconButton(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppTheme.coral,
              tooltip: 'Borrar plato',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: <Widget>[
            _Field(
              controller: _name,
              label: 'Nombre',
              hint: 'Pupusa de queso',
              validator: _validateName,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              controller: _description,
              label: 'Descripción (opcional)',
              hint: 'Hecha a mano, con curtido y salsa.',
              validator: _validateDescription,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              controller: _price,
              label: 'Precio',
              hint: '1.50',
              validator: _validatePrice,
              prefixText: '\$ ',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // Deja escribir solo numeros y punto: menos errores de tipeo.
              // Ojo, esto NO valida: "1.2.3" pasa el filtro y lo rechaza
              // _validatePrice, que es el que manda.
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _CategoryPicker(
              categories: widget.categories,
              value: _categoryId,
              onChanged: (int? value) => setState(() => _categoryId = value),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _ErrorBox(message: _error!),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Guardar cambios' : 'Agregar al menú',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un campo del formulario, con el mismo aspecto para los tres.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.validator,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.prefixText,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? prefixText;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      // Valida mientras escribe, no solo al guardar: el error aparece al
      // lado del campo que lo tiene, no como un golpe al final.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        // El "$ " del precio va en la DECORACION, no en el campo: prefixText
        // es de InputDecoration, no de TextFormField.
        prefixText: prefixText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.image),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Donde va el plato: botones y no un desplegable.
///
/// Un restaurante tiene pocas categorias, asi que verlas todas de una es mas
/// rapido que abrir una lista. Si algun dia son veinte, se cambia por un
/// desplegable y listo: la pantalla no se entera.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<MenuCategory> categories;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Categoría',
          style: text.labelLarge?.copyWith(
            color: AppTheme.navy,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            ChoiceChip(
              label: const Text('Sin categoría'),
              selected: value == null,
              onSelected: (_) => onChanged(null),
            ),
            for (final MenuCategory category in categories)
              ChoiceChip(
                label: Text(category.name),
                selected: value == category.id,
                onSelected: (_) => onChanged(category.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// El aviso de error que devolvio el backend.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.tealSoft,
        borderRadius: BorderRadius.circular(AppRadius.image),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, color: AppTheme.coral),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: text.bodyMedium?.copyWith(color: AppTheme.navy),
            ),
          ),
        ],
      ),
    );
  }
}
