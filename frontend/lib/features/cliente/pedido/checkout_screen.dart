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

  bool _loading = true;
  bool _sending = false;
  String? _error;
  String _selectedTip = '0.00';
  bool _customTip = false;
  final TextEditingController _tipController = TextEditingController();

  @override
  void dispose() {
    _tipController.dispose();
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

  Future<void> _load({int? selectedAddressId}) async {
    setState(() {
      _loading = true;
      _error = null;
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
      });

      if (selected != null) {
        await _resolveFee(selected);
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
  Future<void> _resolveFee(Address address) async {
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

      if (!mounted) {
        return;
      }

      setState(() {
        _deliveryFee = detail.restaurant.deliveryFee;
        _feeReady = true;
      });
    } on ApiException catch (error) {
      if (!mounted) {
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
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (BuildContext context) =>
          _AddressPicker(addresses: _addresses, selectedId: _address?.id),
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
    final Address? previous = _address;

    try {
      final ApiClient api = await _session.client();
      final List<Address> addresses = await AddressRepository(api).load();

      if (!mounted) {
        return;
      }

      setState(() {
        _addresses = addresses;

        // Si la que tenia elegida ya no existe (la borro desde "Administrar"),
        // se suelta y queda la primera.
        if (previous != null &&
            !addresses.any((Address item) => item.id == previous.id)) {
          _address = addresses.isEmpty ? null : addresses.first;
        }
      });

      // Y si cambio la elegida, el envio hay que recalcularlo para la nueva.
      final Address? current = _address;

      if (current != null && current.id != previous?.id) {
        await _resolveFee(current);
      }
    } on ApiException catch (_) {
      // Si falla, se deja la lista que ya teniamos: no vale la pena molestar al
      // cliente con eso justo despues de que acaba de elegir.
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final Cart currentCart = ref.watch(cartProvider);
    final Cart cart = _pending?.cart ?? currentCart;
    final TextTheme text = Theme.of(context).textTheme;

    final bool canConfirm =
        !_loading &&
        !_sending &&
        _tipError == null &&
        _repository != null &&
        (_pending != null ||
            (_address != null && _deliveryFee != null && cart.isNotEmpty));

    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Confirmar pedido',
            style: text.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                children: <Widget>[
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
                  _CheckoutCard(
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
                  _CheckoutCard(
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
                              color: AppTheme.tealDeep,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'El 100% es para el motorista. La pagás al recibir.',
                        style: text.bodySmall?.copyWith(
                          color: AppTheme.tealDeep,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          for (final String amount in <String>[
                            '0.00',
                            '0.50',
                            '1.00',
                            '2.00',
                          ])
                            ChoiceChip(
                              showCheckmark: false,
                              side: WidgetStateBorderSide.resolveWith(
                                (states) => BorderSide(
                                  color: states.contains(WidgetState.selected)
                                      ? AppTheme.teal
                                      : Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                ),
                              ),
                              selectedColor: AppTheme.tealSoft,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surface,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              labelStyle: text.labelLarge?.copyWith(
                                color: AppTheme.tealDeep,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.sm,
                                ),
                              ),
                              label: Text(
                                amount == '0.00' ? 'Sin propina' : '\$$amount',
                              ),
                              selected: !_customTip && _tipAmount == amount,
                              onSelected: _pending != null || _sending
                                  ? null
                                  : (_) => setState(() {
                                      _selectedTip = amount;
                                      _customTip = false;
                                    }),
                            ),
                          ChoiceChip(
                            showCheckmark: false,
                            side: WidgetStateBorderSide.resolveWith(
                              (states) => BorderSide(
                                color: states.contains(WidgetState.selected)
                                    ? AppTheme.teal
                                    : Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                              ),
                            ),
                            selectedColor: AppTheme.tealSoft,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            labelStyle: text.labelLarge?.copyWith(
                              color: AppTheme.tealDeep,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.sm,
                              ),
                            ),
                            label: const Text('Otro monto'),
                            selected:
                                _customTip ||
                                (_pending != null &&
                                    !<String>[
                                      '0.00',
                                      '0.50',
                                      '1.00',
                                      '2.00',
                                    ].contains(_tipAmount)),
                            onSelected: _pending != null || _sending
                                ? null
                                : (_) => setState(() => _customTip = true),
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
                            fillColor: Theme.of(context).colorScheme.surface,
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
                  _CheckoutCard(
                    children: <Widget>[
                      const _SectionTitle('Resumen'),
                      _SummaryRow(label: 'Platos', value: '\$${cart.subtotal}'),
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.payments_outlined,
                            size: 18,
                            color: AppTheme.teal,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'Pagás en efectivo al recibir',
                              style: text.bodySmall?.copyWith(
                                color: AppTheme.navy,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    _ErrorBox(message: _error!),
                    TextButton(
                      onPressed: _sending ? null : _load,
                      child: const Text('Actualizar'),
                    ),
                  ],
                ],
              ),
        bottomNavigationBar: _loading
            ? null
            : Material(
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _SummaryRow(
                          label: 'Total',
                          value: _deliveryFee == null ? '—' : '\$$_total',
                          strong: true,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: canConfirm ? _confirm : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.coralDeep,
                              minimumSize: const Size.fromHeight(54),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.image,
                                ),
                              ),
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Flexible(
                                        child: Text(
                                          _pending == null
                                              ? 'Confirmar pedido'
                                              : 'Recuperar pedido',
                                          textAlign: TextAlign.center,
                                          style: text.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          ),
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
                              color: AppTheme.coral,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Agrupa las secciones del checkout con la misma superficie y espaciado.
class _CheckoutCard extends StatelessWidget {
  const _CheckoutCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.image),
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
          color: AppTheme.navy,
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
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.image),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              const Icon(Icons.place_rounded, color: AppTheme.teal),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: address == null
                    ? Text(
                        'Elegí una dirección',
                        style: text.titleSmall?.copyWith(color: AppTheme.navy),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            address!.label,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy,
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
              const Icon(Icons.expand_more_rounded, color: AppTheme.navy),
            ],
          ),
        ),
      ),
    );
  }
}

/// Permite quitar platos antes de confirmar; bloqueada mientras hay un intento pendiente.
class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item, this.onRemove});

  final CartItem item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppTheme.tealSoft,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Text(
              '${item.quantity}×',
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.tealDeep,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              item.product.name,
              style: text.bodyMedium?.copyWith(color: AppTheme.navy),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '\$${item.subtotal}',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
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
}

/// Una fila del resumen: "Platos $3.00".
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.hint,
    this.strong = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    final TextStyle? style = strong
        ? text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          )
        : text.bodyMedium?.copyWith(color: AppTheme.navy);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label, style: style)),
              Text(
                value,
                style: strong
                    ? text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.coral,
                      )
                    : text.bodyMedium?.copyWith(color: AppTheme.navy),
              ),
            ],
          ),
          if (hint != null)
            Text(hint!, style: text.bodySmall?.copyWith(color: AppTheme.coral)),
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
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.tealSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '¿Dónde te lo llevamos?',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar direcciones',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: AppTheme.navy,
                ),
              ],
            ),
            Text(
              'Elegí una dirección para este pedido.',
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (addresses.isEmpty)
              Text(
                'Todavía no tenés direcciones guardadas.',
                style: text.bodyMedium,
              ),
            for (final address in addresses)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Semantics(
                  selected: address.id == selectedId,
                  child: Material(
                    color: address.id == selectedId
                        ? AppTheme.tealSoft
                        : Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.image),
                      side: BorderSide(
                        color: address.id == selectedId
                            ? AppTheme.teal
                            : Colors.transparent,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.of(
                        context,
                      ).pop(_PickerResult(_PickerAction.pick, address)),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.place_outlined,
                              color: AppTheme.tealDeep,
                              size: 22,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Wrap(
                                    spacing: AppSpacing.xs,
                                    runSpacing: AppSpacing.xs,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        address.label,
                                        style: text.titleSmall?.copyWith(
                                          color: AppTheme.navy,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (address.isDefault)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.tealSoft,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Predeterminada',
                                            style: text.labelSmall?.copyWith(
                                              color: AppTheme.tealDeep,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    address.address,
                                    style: text.bodySmall?.copyWith(
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              address.id == selectedId
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: AppTheme.tealDeep,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).pop(const _PickerResult(_PickerAction.create)),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva dirección'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: AppTheme.tealDeep,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.image),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Center(
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
