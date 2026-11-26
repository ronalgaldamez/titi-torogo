import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/money.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/address.dart';
import '../../../models/order.dart';
import '../carrito/cart.dart';
import '../carrito/cart_provider.dart';
import '../checkout_appearance.dart';
import '../direcciones/address_form_screen.dart';
import '../direcciones/address_repository.dart';
import '../direcciones/addresses_screen.dart';
import '../restaurante/restaurant_detail_repository.dart';
import 'order_repository.dart';
import 'order_sent_screen.dart';
import 'pending_order_storage.dart';

/// El checkout: elegir a donde se entrega y confirmar el pedido.
///
/// Es la pantalla donde el cliente dice "si" por primera vez, asi que todo lo
/// que va a pagar tiene que estar a la vista ANTES del boton: los platos, el
/// envio y el total.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  OrderRepository? _repository;
  PendingOrder? _pending;

  Cart get _cart => _pending?.cart ?? ref.read(cartProvider);

  final Session _session = Session(AuthStorage());

  List<Address> _addresses = <Address>[];
  Address? _address;

  /// La tarifa de envio PARA LA DIRECCION elegida. null puede significar dos
  /// cosas distintas, y por eso existe [_feeReady]:
  ///
  ///   _feeReady == false  -> todavia la estamos resolviendo
  ///   _feeReady == true   -> el backend dijo que NO se puede entregar ahi
  String? _deliveryFee;
  bool _feeReady = false;
  int _feeVersion = 0;

  bool _loading = true;
  bool _sending = false;
  String? _error;
  final ScrollController _scroll = ScrollController();
  String _selectedTip = '0.00';
  bool _customTip = false;
  final TextEditingController _tipController = TextEditingController();

  @override
  void dispose() {
    _tipController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String? get _tipError {
    if (!_customTip || _pending != null) {
      return null;
    }
    final String value = _tipController.text.trim().replaceAll(',', '.');
    if (!RegExp(r'^\d{1,3}(?:\.\d{1,2})?$').hasMatch(value) ||
        Money.toCents(value) > 10000) {
      return 'Ingresá entre \$0.00 y \$100.00, con hasta dos decimales.';
    }
    return null;
  }

  String get _tipAmount =>
      _pending?.tipAmount ??
      (_customTip && _tipError == null
          ? Money.fromCents(
              Money.toCents(_tipController.text.trim().replaceAll(',', '.')),
            )
          : _selectedTip);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({
    int? selectedAddressId,
    bool refreshPrices = false,
  }) async {
    _feeVersion++;
    setState(() {
      _loading = true;
      _error = null;
      _deliveryFee = null;
      _feeReady = false;
    });

    try {
      final ApiClient api = await _session.client();
      final OrderRepository repository = OrderRepository(api);
      _repository = repository;
      final PendingOrder? pending = await repository.loadPending();
      if (!mounted) {
        return;
      }
      if (pending != null) {
        setState(() {
          _pending = pending;
          _address = pending.address;
          _deliveryFee = pending.deliveryFee;
          _feeReady = true;
          _loading = false;
        });
        return;
      }
      final List<Address> addresses = await AddressRepository(api).load();

      if (!mounted) {
        return;
      }

      Address? selected;

      for (final Address address in addresses) {
        if (address.id == selectedAddressId) {
          selected = address;
          break;
        }
      }

      for (final Address address in addresses) {
        if (selected == null && address.isDefault) {
          selected = address;
          break;
        }
      }

      selected ??= addresses.isEmpty ? null : addresses.first;

      setState(() {
        _pending = null;
        _addresses = addresses;
        _address = selected;
        _loading = false;
        _feeReady = selected == null;
      });

      if (selected != null) {
        await _resolveFee(selected, refreshPrices: refreshPrices);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// Pide la tarifa de envio PARA ESA DIRECCION.
  ///
  /// Se reusa el detalle del restaurante pasandole las coordenadas de la
  /// DIRECCION en vez de las del cliente. El backend resuelve en que zona cae
  /// y devuelve la tarifa — con la misma cuenta que va a hacer al crear el
  /// pedido, asi que lo que se ve y lo que se cobra salen del mismo codigo.
  ///
  /// Y de paso resuelve la otra pregunta: si la tarifa vuelve null, esa
  /// direccion queda FUERA de toda zona de reparto, y hay que decirlo antes
  /// de dejar confirmar.
  Future<void> _resolveFee(
    Address address, {
    bool refreshPrices = false,
  }) async {
    final version = ++_feeVersion;
    final int? restaurantId = ref.read(cartProvider).restaurantId;

    if (restaurantId == null) {
      return;
    }

    setState(() {
      _deliveryFee = null;
      _feeReady = false;
    });

    try {
      final RestaurantDetail detail =
          await RestaurantDetailRepository(ApiClient()).load(
            restaurantId,
            latitude: address.latitude,
            longitude: address.longitude,
          );

      if (!mounted || version != _feeVersion) {
        return;
      }

      final pricesChanged =
          refreshPrices &&
          await ref
              .read(cartProvider.notifier)
              .refreshPrices(
                restaurantId,
                detail.categories.expand((category) => category.products),
              );
      if (!mounted || version != _feeVersion) return;

      setState(() {
        _deliveryFee = detail.restaurant.deliveryFee;
        _feeReady = true;
        if (pricesChanged) {
          _error =
              'Cambió el precio de uno o más platos. Revisá el nuevo total antes de confirmar.';
        }
      });
    } on ApiException catch (error) {
      if (!mounted || version != _feeVersion) {
        return;
      }

      setState(() {
        _error = error.message;
        _feeReady = true;
      });
    }
  }

  /// El total a pagar: platos, envío y propina seleccionada.
  String get _total =>
      Money.add(<String>[_cart.subtotal, _deliveryFee ?? '0.00', _tipAmount]);

  /// Abre el selector de direcciones.
  ///
  /// El selector puede devolver TRES cosas: que eligio una, que quiere crear una
  /// nueva, o que quiere administrar las que tiene. Por eso devuelve un
  /// [_PickerResult] y no un `Address?`: "no eligio nada" y "quiere crear una"
  /// no son lo mismo.
  Future<void> _openAddressPicker() async {
    if (_pending != null || _sending) {
      return;
    }
    final _PickerResult? result = await showModalBottomSheet<_PickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: flowSheet,
      barrierColor: const Color(0xA6040E17),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (context) => Theme(
        data: checkoutTheme(context),
        child: Material(
          type: MaterialType.transparency,
          child: _AddressPicker(
            addresses: _addresses,
            selectedId: _address?.id,
          ),
        ),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.action == _PickerAction.pick) {
      final Address address = result.address!;

      setState(() => _address = address);

      await _resolveFee(address);
      return;
    }

    if (result.action == _PickerAction.create) {
      final Address? created = await Navigator.of(context).push<Address>(
        MaterialPageRoute<Address>(
          builder: (BuildContext context) => const AddressFormScreen(),
        ),
      );

      if (!mounted) {
        return;
      }

      await _reloadAddresses();

      if (!mounted || created == null) {
        return;
      }

      // Si acaba de crear una, se elige sola: es la que quiere usar.
      setState(() => _address = created);

      await _resolveFee(created);
      return;
    }

    // Administrar: la pantalla completa, donde puede editar y borrar.
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AddressesScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _reloadAddresses();
  }

  /// Recarga SOLO la lista de direcciones, sin pisar cual esta elegida.
  ///
  /// No se usa _load() porque ese elige la predeterminada, y aca el cliente ya
  /// eligio: pisarle la eleccion seria peor que no recargar.
  Future<void> _reloadAddresses() async {
    final previousId = _address?.id;
    _feeVersion++;
    setState(() {
      _deliveryFee = null;
      _feeReady = false;
    });
    try {
      final api = await _session.client();
      final addresses = await AddressRepository(api).load();
      if (!mounted) return;
      Address? selected;
      for (final address in addresses) {
        if (address.id == previousId) selected = address;
      }
      selected ??= addresses.isEmpty ? null : addresses.first;
      setState(() {
        _addresses = addresses;
        _address = selected;
        _feeReady = selected == null;
      });
      if (selected != null) await _resolveFee(selected);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _feeReady = true;
      });
    }
  }

  Future<void> _confirm() async {
    final Cart cart = _cart;
    final Address? address = _address;
    final OrderRepository? repository = _repository;

    if (_sending ||
        _tipError != null ||
        repository == null ||
        (_pending == null &&
            (address == null || cart.isEmpty || _deliveryFee == null))) {
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final PendingOrder? original = _pending;
      final Order? recovered = original != null
          ? await repository.recoverPending()
          : null;
      if (original != null && recovered == null) {
        if (ref.read(cartProvider).isEmpty) {
          await ref.read(cartProvider.notifier).restore(original.cart);
        }
        await repository.complete();
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedTip = original.tipAmount;
          _customTip = false;
          _pending = null;
          _sending = false;
        });
        await _load(selectedAddressId: original.address.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Carrito recuperado. Podés modificarlo y después confirmar. No se envió ningún pedido.',
              ),
            ),
          );
        }
        return;
      }

      final Order order =
          recovered ??
          await repository.create(
            cart: cart,
            address: address!,
            deliveryFee: _deliveryFee!,
            tipAmount: _tipAmount,
          );

      // El carrito se vacia DESPUES de que el backend confirme el pedido.
      // Si se vaciara antes y la peticion fallara, el cliente se quedaria sin
      // pedido Y sin carrito — o sea, cargando todo de nuevo.
      final PendingOrder? submitted = await repository.loadPending();
      if (submitted != null && submitted.matchesCart(ref.read(cartProvider))) {
        await ref.read(cartProvider.notifier).clear();
      }
      await repository.complete();

      if (!mounted) {
        return;
      }

      // pushReplacement: el checkout de un pedido ya hecho no tiene por que
      // quedar en el historial de atras.
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => OrderSentScreen(
            orderId: order.id,
            restaurantName: order.restaurant.name,
            total: order.total,
            tipAmount: order.tipAmount,
            alreadySent: original != null,
          ),
        ),
      );
    } catch (error) {
      // Incluye respuestas ilegibles: pudieron llegar DESPUES de guardar el pedido.
      PendingOrder? pending = _pending;
      String message = error is ApiException
          ? error.message
          : 'No pudimos confirmar la respuesta. Reintentá para recuperar el mismo pedido.';
      try {
        pending = await repository.loadPending();
      } catch (_) {
        message =
            'No pudimos leer el intento guardado. Volvé a abrir esta pantalla antes de volver a pedir.';
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _sending = false;
        _pending = pending;
        if (pending != null) {
          _address = pending.address;
          _deliveryFee = pending.deliveryFee;
          _feeReady = true;
        }
        _error = message;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }
        if (_scroll.hasClients) {
          await _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
      if (pending == null &&
          error is ApiException &&
          error.statusCode == 422 &&
          address != null) {
        if (error.validationFields.contains('expected_address_version')) {
          await _reloadAddresses();
        } else {
          await _resolveFee(
            address,
            refreshPrices: error.validationFields.contains('items'),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Cart currentCart = ref.watch(cartProvider);
    final Cart cart = _pending?.cart ?? currentCart;
    final theme = checkoutTheme(context);
    final text = theme.textTheme;
    const tipPresets = ['0.00', '0.50', '1.00', '2.00'];

    final bool canConfirm =
        !_loading &&
        !_sending &&
        _tipError == null &&
        _repository != null &&
        (_pending != null ||
            (_address != null && _deliveryFee != null && cart.isNotEmpty));

    return PopScope(
      canPop: !_sending,
      child: Theme(
        data: theme,
        child: Scaffold(
          backgroundColor: AppTheme.discoveryBackground,
          appBar: checkoutAppBar(),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
                  children: <Widget>[
                    CheckoutHeading(
                      'Confirmar pedido',
                      caption: cart.restaurantName,
                    ),
                    const SizedBox(height: 16),
                    if (_pending != null) ...<Widget>[
                      const _ErrorBox(
                        message:
                            'Revisá si el pedido llegó al restaurante. Recuperar no envía un pedido nuevo.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const _SectionTitle('Entregar en'),
                    _AddressCard(address: _address, onTap: _openAddressPicker),
                    const SizedBox(height: AppSpacing.sm),
                    _CheckoutSection(
                      children: <Widget>[
                        const _SectionTitle('Tu pedido'),
                        for (final CartItem item in cart.items)
                          _ItemLine(
                            item: item,
                            onRemove: _pending != null || _sending
                                ? null
                                : () => ref
                                      .read(cartProvider.notifier)
                                      .remove(item.product.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CheckoutSection(
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Expanded(
                              child: _SectionTitle('Propina al motorista'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Opcional',
                              style: text.labelSmall?.copyWith(
                                color: AppTheme.discoveryMuted,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'El 100% es para el motorista. La pagás al recibir.',
                          style: text.bodySmall?.copyWith(
                            color: AppTheme.discoveryMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final amount in [...tipPresets, null])
                              ChoiceChip(
                                showCheckmark: false,
                                side: const BorderSide(color: flowRule),
                                color: WidgetStateProperty.resolveWith(
                                  (states) =>
                                      states.contains(WidgetState.selected)
                                      ? AppTheme.discoveryPaper
                                      : AppTheme.discoveryBackground,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.xs,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.padded,
                                labelStyle: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: WidgetStateColor.resolveWith(
                                    (states) =>
                                        states.contains(WidgetState.selected)
                                        ? AppTheme.discoveryBackground
                                        : AppTheme.discoveryPaper,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                label: Text(switch (amount) {
                                  null => 'Otro monto',
                                  '0.00' => 'Sin propina',
                                  _ => '\$$amount',
                                }),
                                selected: amount == null
                                    ? _customTip ||
                                          (_pending != null &&
                                              !tipPresets.contains(_tipAmount))
                                    : !_customTip && _tipAmount == amount,
                                onSelected: _pending != null || _sending
                                    ? null
                                    : (_) => setState(() {
                                        _customTip = amount == null;
                                        if (amount != null) {
                                          _selectedTip = amount;
                                        }
                                      }),
                              ),
                          ],
                        ),
                        if (_customTip && _pending == null) ...<Widget>[
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: _tipController,
                            enabled: !_sending,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Propina personalizada',
                              prefixText: '\$ ',
                              helperText: 'Hasta \$100.00',
                              errorText: _tipError,
                              filled: true,
                              fillColor: flowField,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.sm,
                                ),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _CheckoutSection(
                      children: <Widget>[
                        const _SectionTitle('Resumen'),
                        _SummaryRow(
                          label: 'Platos',
                          value: '\$${cart.subtotal}',
                        ),
                        _SummaryRow(
                          label: 'Envío',
                          value: _feeReady
                              ? (_deliveryFee == null ? '—' : '\$$_deliveryFee')
                              : '...',
                          hint: _feeReady && _deliveryFee == null
                              ? 'No llegamos a esa dirección'
                              : null,
                        ),
                        _SummaryRow(label: 'Propina', value: '\$$_tipAmount'),
                      ],
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      _ErrorBox(message: _error!),
                      TextButton(
                        onPressed: _sending
                            ? null
                            : () => _load(
                                selectedAddressId: _address?.id,
                                refreshPrices: true,
                              ),
                        child: const Text('Actualizar'),
                      ),
                    ],
                  ],
                ),
          bottomNavigationBar: _loading
              ? null
              : Material(
                  color: flowSheet,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: flowRule)),
                      ),
                      padding: const EdgeInsets.fromLTRB(22, 11, 22, 13),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      'Pagás en efectivo al recibir',
                                      style: TextStyle(
                                        color: AppTheme.discoveryMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _deliveryFee == null ? '—' : '\$$_total',
                                style: const TextStyle(
                                  color: AppTheme.discoveryAccent,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          CheckoutAction(
                            _pending == null
                                ? 'Confirmar pedido'
                                : 'Recuperar pedido',
                            onPressed: canConfirm ? _confirm : null,
                            loading: _sending,
                          ),
                          if (!canConfirm &&
                              !_sending &&
                              _tipError == null) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _feeReady && _deliveryFee == null
                                  ? 'Todavía no llegamos a esa dirección. Probá con otra.'
                                  : 'Elegí una dirección para continuar.',
                              textAlign: TextAlign.center,
                              style: text.bodySmall?.copyWith(
                                color: AppTheme.discoveryAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Separa los bloques del pedido con una línea fina.
class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: flowRule)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

/// El titulo de una seccion.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        title,
        style: text.titleSmall?.copyWith(
          color: AppTheme.discoveryPaper,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// La direccion elegida, con el boton para cambiarla.
class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onTap});

  final Address? address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Material(
      color: flowSheet,
      borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppTheme.discoveryAccent, width: 3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: <Widget>[
              const Icon(Icons.place_outlined, color: AppTheme.discoveryAccent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: address == null
                    ? Text(
                        'Elegí una dirección',
                        style: text.titleSmall?.copyWith(
                          color: AppTheme.discoveryPaper,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            address!.label,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.discoveryPaper,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            address!.address,
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          if (address!.reference != null &&
                              address!.reference!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              address!.reference!,
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Cambiar',
                style: TextStyle(color: flowMint, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Permite quitar platos antes de confirmar.
class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item, this.onRemove});

  final CartItem item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        CheckoutThumbnail(item.product.imageUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${item.quantity} × \$${item.product.price}',
                style: const TextStyle(color: AppTheme.discoveryMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '\$${item.subtotal}',
          style: const TextStyle(
            color: AppTheme.discoveryAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (onRemove != null)
          IconButton(
            onPressed: onRemove,
            tooltip: 'Quitar plato',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
      ],
    ),
  );
}

/// Una fila del resumen: "Platos $3.00".
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    final style = text.bodyMedium?.copyWith(color: AppTheme.discoveryMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label, style: style)),
              Text(value, style: text.bodyMedium),
            ],
          ),
          if (hint != null)
            Text(
              hint!,
              style: text.bodySmall?.copyWith(color: AppTheme.discoveryAccent),
            ),
        ],
      ),
    );
  }
}

/// Que puede responder el selector de direcciones.
enum _PickerAction { pick, create, manage }

/// La respuesta del selector: que quiso hacer el cliente, y cual eligio si
/// eligio alguna.
class _PickerResult {
  const _PickerResult(this.action, [this.address]);

  final _PickerAction action;
  final Address? address;
}

/// La lista de direcciones para elegir.
class _AddressPicker extends StatelessWidget {
  const _AddressPicker({required this.addresses, required this.selectedId});

  final List<Address> addresses;
  final int? selectedId;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: CheckoutHeading('¿Dónde te lo llevamos?')),
              IconButton(
                tooltip: 'Cerrar direcciones',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (addresses.isEmpty)
            const Text('Todavía no tenés direcciones guardadas.'),
          for (final address in addresses) ...[
            Semantics(
              selected: address.id == selectedId,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  address.id == selectedId
                      ? Icons.check_circle_outline_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: address.id == selectedId
                      ? flowMint
                      : AppTheme.discoveryMuted,
                ),
                title: Text(
                  address.label,
                  style: TextStyle(
                    color: address.id == selectedId
                        ? flowMint
                        : AppTheme.discoveryPaper,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(address.address),
                    if (address.isDefault) const Text('Predeterminada'),
                  ],
                ),
                onTap: () => Navigator.of(
                  context,
                ).pop(_PickerResult(_PickerAction.pick, address)),
              ),
            ),
            const Divider(height: 1),
          ],
          const SizedBox(height: AppSpacing.md),
          CheckoutAction(
            'Nueva dirección',
            icon: Icons.add_rounded,
            onPressed: () => Navigator.of(
              context,
            ).pop(const _PickerResult(_PickerAction.create)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(const _PickerResult(_PickerAction.manage)),
              child: const Text('Administrar mis direcciones'),
            ),
          ),
        ],
      ),
    ),
  );
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
        color: flowSheet,
        borderRadius: BorderRadius.circular(AppRadius.image),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.discoveryAccent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: text.bodyMedium?.copyWith(color: AppTheme.discoveryPaper),
            ),
          ),
        ],
      ),
    );
  }
}
