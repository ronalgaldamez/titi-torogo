import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/location.dart';
import '../../../core/theme.dart';
import '../../../models/delivery_zone.dart';
import '../../../models/restaurant.dart';
import '../pedido/my_orders_screen.dart';
import '../../shared/account_profile.dart';
import '../restaurante/restaurant_detail_screen.dart';
import 'home_repository.dart';
import 'widgets/restaurant_card.dart';

/// El Home del cliente: los restaurantes que SI entregan donde esta.
///
/// No es "los mas cercanos": es la interseccion entre su ubicacion y las
/// zonas de reparto que dibujamos en Google My Maps.
class HomeScreen extends StatefulWidget {
  const HomeScreen({this.onLogout, super.key});

  /// Cerrar sesion. Si viene null, NO se muestra el boton: pasa cuando el
  /// usuario entro con "Explorar sin cuenta" y no tiene sesion que cerrar.
  final Future<void> Function()? onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Donde creemos que esta el cliente.
  ///
  /// Arranca en la ubicacion de respaldo y se reemplaza por la del telefono en
  /// cuanto llega. La marca `isReal` es la que decide si mostramos el aviso de
  /// "ubicacion aproximada".
  Place _place = LocationService.fallback;

  late final HomeRepository _repository;
  late Future<HomeData> _future;
  int _tab = 0;
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _repository = HomeRepository(ApiClient());
    _future = _start();
  }

  /// Pide la ubicacion y DESPUES carga los restaurantes.
  ///
  /// El orden importa: el Home no pregunta "que restaurantes hay", pregunta
  /// "que puedo entregar DONDE ESTAS". Sin la ubicacion no hay que preguntar.
  Future<HomeData> _start() async {
    final Place place = await LocationService().current();

    if (mounted) {
      setState(() => _place = place);
    }

    return _load();
  }

  Future<HomeData> _load() {
    return _repository.load(
      latitude: _place.latitude,
      longitude: _place.longitude,
    );
  }

  Future<void> _reload() async {
    // Al deslizar se vuelve a preguntar la ubicacion: el cliente pudo haberse
    // movido, y para eso esta el gesto.
    final Future<HomeData> next = _start();

    setState(() {
      _future = next;
    });

    try {
      // Se espera el resultado para que el indicador de "desliza para
      // actualizar" desaparezca cuando la peticion realmente termino.
      await next;
    } catch (_) {
      // El error ya lo muestra el FutureBuilder. Aqui solo evitamos que
      // la excepcion quede sin manejar.
    }
  }

  /// Abre la carta del restaurante.
  ///
  /// Se le pasa la MISMA ubicacion con la que se cargo el Home: con eso el
  /// backend resuelve la distancia y la tarifa de envio del detalle, y los
  /// numeros que se ven en la carta coinciden con los de la tarjeta.
  void _openRestaurant(Restaurant restaurant) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RestaurantDetailScreen(
          restaurant: restaurant,
          latitude: _place.latitude,
          longitude: _place.longitude,
        ),
      ),
    );
  }

  /// Pide confirmacion antes de cerrar sesion.
  ///
  /// Cerrar sesion es una accion que se toca sin querer, y deshacerla
  /// significa volver a escribir la contrasena. Un dialogo de por medio
  /// evita ese enojo.
  Future<void> _confirmLogout() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('¿Cerrar sesion?'),
            content: const Text(
              'Vas a salir de tu cuenta en este dispositivo. '
              'Tus pedidos y direcciones quedan guardados.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cerrar sesion'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await widget.onLogout?.call();
    }
  }

  void _comingSoon(String feature) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(feature, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Próximamente. Esta función todavía no está disponible.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profile() {
    if (widget.onLogout != null) {
      return AccountProfile(onLogout: _confirmLogout);
    }
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Text(
          widget.onLogout == null
              ? 'Explorando sin cuenta'
              : 'Tu cuenta en Toro Go',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        const Text('Perfil del cliente · Próximamente'),
        const SizedBox(height: AppSpacing.lg),
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: Column(
            children: const <Widget>[
              ListTile(
                leading: Icon(Icons.person_outline_rounded),
                title: Text('Información personal'),
                subtitle: Text('Próximamente'),
              ),
              ListTile(
                leading: Icon(Icons.favorite_border_rounded),
                title: Text('Favoritos'),
                subtitle: Text('Próximamente'),
              ),
              ListTile(
                leading: Icon(Icons.notifications_none_rounded),
                title: Text('Notificaciones'),
                subtitle: Text('Próximamente'),
              ),
            ],
          ),
        ),
        if (widget.onLogout != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          setState(() => _tab = 0);
        }
      },
      child: Scaffold(
        appBar: _tab == 1 && widget.onLogout != null
            ? null
            : AppBar(
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: AppTheme.background,
                title: _tab == 0 ? const _Wordmark() : const Text('Perfil'),
                actions: _tab == 0
                    ? <Widget>[
                        IconButton(
                          onPressed: () => _comingSoon('Notificaciones'),
                          tooltip: 'Notificaciones · Próximamente',
                          icon: const Icon(Icons.notifications_none_rounded),
                        ),
                        IconButton(
                          onPressed: _reload,
                          tooltip: 'Actualizar',
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ]
                    : null,
              ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: AppTheme.tealSoft,
          selectedIndex: _tab,
          onDestinationSelected: (index) {
            if (index == 1 && widget.onLogout == null) {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Tus pedidos'),
                  content: const Text(
                    'Iniciá sesión para consultar tus pedidos.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendido'),
                    ),
                  ],
                ),
              );
              return;
            }
            setState(() => _tab = index);
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Pedidos',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
        body: _tab == 1
            ? const MyOrdersScreen()
            : _tab == 2
            ? _profile()
            : _home(),
      ),
    );
  }

  Widget _home() {
    return FutureBuilder<HomeData>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<HomeData> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingList();
        }

        if (snapshot.hasError) {
          return _MessageState(
            icon: Icons.wifi_off_rounded,
            title: 'No pudimos cargar los restaurantes',
            message: '${snapshot.error}',
            onRetry: _reload,
          );
        }

        final HomeData data = snapshot.data!;

        if (data.isOutsideCoverage) {
          return const _MessageState(
            icon: Icons.location_off_rounded,
            title: 'Todavia no llegamos ahi',
            message:
                'Estamos empezando en esta zona. '
                'Pronto vamos a cubrir mas lugares.',
          );
        }

        final String query = _search.text.trim().toLowerCase();
        final List<Restaurant> restaurants = data.restaurants
            .where(
              (restaurant) => restaurant.name.toLowerCase().contains(query),
            )
            .toList();
        final int total = restaurants.length;

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            key: const PageStorageKey<String>('client-home'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            itemCount: total + 2 + (total == 0 ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return _Header(
                  zone: data.zone!,
                  search: _search,
                  onSearch: () => setState(() {}),
                );
              }

              if (index == 1) {
                return Column(
                  children: <Widget>[
                    // Si el GPS no dio una ubicacion de verdad, se dice. Es
                    // la diferencia entre "esto es lo que hay cerca tuyo" y
                    // "esto es lo que hay cerca de la zona de reparto".
                    //
                    // Y si la dio pero con error de cuadras, tambien: el
                    // cliente tiene que poder entender por que la lista se ve
                    // distinta a lo que esperaba.
                    if (!_place.isReal || _place.isApproximate)
                      _LocationNotice(place: _place),
                    _SectionTitle(count: total),
                  ],
                );
              }

              if (total == 0) {
                return _MessageState(
                  icon: query.isEmpty
                      ? Icons.storefront_outlined
                      : Icons.search_off_rounded,
                  title: query.isEmpty
                      ? 'No hay restaurantes disponibles'
                      : 'No encontramos ese restaurante',
                  message: query.isEmpty
                      ? 'Probá actualizar en unos minutos.'
                      : 'Probá otro nombre o borrá la búsqueda.',
                  onRetry: query.isEmpty
                      ? _reload
                      : () async {
                          _search.clear();
                          setState(() {});
                        },
                );
              }
              final Restaurant restaurant = restaurants[index - 2];

              return RestaurantCard(
                restaurant: restaurant,
                onTap: () => _openRestaurant(restaurant),
              );
            },
          ),
        );
      },
    );
  }
}

/// El aviso de que la ubicacion NO es la del telefono.
///
/// Es una franja chiquita y no un cartel rojo: la app funciona igual, solo que
/// con el punto del Mall del Sol. Asustar al cliente por eso seria peor que el
/// problema que avisa.
///
/// Son DOS avisos distintos, y la diferencia importa:
///
///   - no hay ubicacion: la lista es la de la zona, no la de cerca tuyo.
///   - ubicacion aproximada: la lista si es la de cerca tuyo, solo que el punto
///     puede estar corrido unas cuadras.
///
/// El segundo es mucho mejor que el primero, asi que no se dice igual.
class _LocationNotice extends StatelessWidget {
  const _LocationNotice({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    final String message = place.isApproximate
        ? 'Tu ubicación es aproximada (${place.accuracyText} de error). Si no '
              'ves tu restaurante, salí a un lugar abierto y deslizá para '
              'actualizar.'
        : 'Estamos usando el Mall del Sol como referencia. Activá el GPS '
              'para ver lo que hay cerca tuyo.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppTheme.yellow,
        borderRadius: BorderRadius.circular(AppRadius.image),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            place.isApproximate
                ? Icons.gps_not_fixed_rounded
                : Icons.location_searching_rounded,
            size: 16,
            color: AppTheme.navy,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: text.bodySmall?.copyWith(
                color: AppTheme.navy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El logotipo: "Toro" en color de marca y "Go" en azul marino.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <TextSpan>[
          TextSpan(
            text: 'Toro',
            style: TextStyle(color: AppTheme.teal),
          ),
          TextSpan(
            text: 'Go',
            style: TextStyle(color: AppTheme.navy),
          ),
        ],
      ),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    );
  }
}

/// Zona real de cobertura, búsqueda local y presentación del catálogo.
class _Header extends StatelessWidget {
  const _Header({
    required this.zone,
    required this.search,
    required this.onSearch,
  });
  final DeliveryZone zone;
  final TextEditingController search;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.place_rounded, color: AppTheme.tealDeep, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Entregamos en', style: text.bodySmall),
                  Text(
                    zone.name,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Tarifas de entrega',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Tarifas de entrega'),
                  content: Text(
                    'Envío en la zona: \$${zone.deliveryFee}.\nMotorista: \$${zone.courierFee} + servicio de Toro Go: \$${zone.platformFee}.\nLa tarifa de cada restaurante puede variar; revisá su tarjeta y el total antes de confirmar.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Entendido'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: search,
          onChanged: (_) => onSearch(),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            hintText: 'Buscar restaurantes',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      search.clear();
                      onSearch();
                    },
                  ),
            filled: true,
            fillColor: colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.image),
              borderSide: BorderSide(color: colors.outlineVariant),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Categorías · Próximamente',
          style: text.labelMedium?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final entry in const <String, IconData>{
                'Pupusas': Icons.restaurant_rounded,
                'Hamburguesas': Icons.lunch_dining_rounded,
                'Pollo': Icons.restaurant_menu_rounded,
                'Tacos': Icons.fastfood_rounded,
                'Comida típica': Icons.rice_bowl_rounded,
              }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: Semantics(
                    enabled: false,
                    label: '${entry.key}, próximamente',
                    excludeSemantics: true,
                    child: Column(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppTheme.tealSoft,
                            borderRadius: BorderRadius.circular(
                              AppRadius.image,
                            ),
                          ),
                          child: Icon(
                            entry.value,
                            color: AppTheme.tealDeep,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(entry.key, style: text.labelMedium),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.tealDeep,
            borderRadius: BorderRadius.circular(AppRadius.image),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'El sabor de tu zona',
                        style: text.titleLarge?.copyWith(
                          color: colors.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Descubrí restaurantes locales y elegí qué comer hoy.',
                        style: text.bodySmall?.copyWith(
                          color: colors.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Image.asset(
                  'assets/login.jpg',
                  width: 96,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Titulo de seccion con el conteo, como en las referencias.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(
          child: Text(
            'Restaurantes para vos',
            style: text.titleMedium?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$count restaurantes',
          style: text.bodySmall?.copyWith(color: AppTheme.teal),
        ),
      ],
    );
  }
}

/// Mientras carga: bloques grises con la FORMA del contenido que va a venir.
///
/// Es mejor que un circulo girando: la pantalla no "salta" cuando llegan
/// los datos, porque el esqueleto ya ocupaba el mismo lugar.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: const <Widget>[
        _SkeletonBlock(width: 250, height: 30),
        SizedBox(height: AppSpacing.md),
        _SkeletonBlock(width: double.infinity, height: 120),
        SizedBox(height: AppSpacing.md),
        _SkeletonCard(),
        SizedBox(height: AppSpacing.md),
        _SkeletonCard(),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.image),
      ),
      child: const Row(
        children: <Widget>[
          _SkeletonBlock(width: 88, height: 104),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SkeletonBlock(width: 140, height: 18),
                SizedBox(height: AppSpacing.sm),
                _SkeletonBlock(width: double.infinity, height: 12),
                SizedBox(height: AppSpacing.md),
                _SkeletonBlock(width: 110, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Pantalla completa de error o de aviso, con boton para reintentar.
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: AppTheme.teal),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
