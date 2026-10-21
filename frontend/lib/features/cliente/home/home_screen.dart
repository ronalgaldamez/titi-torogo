import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_client.dart';
import '../../../core/location.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/food_category_icon.dart';
import '../../../models/delivery_zone.dart';
import '../../../models/restaurant.dart';
import '../../../models/food_category.dart';
import '../pedido/my_orders_screen.dart';
import '../../shared/account_profile.dart';
import '../restaurante/restaurant_detail_screen.dart';
import 'home_repository.dart';
import 'widgets/restaurant_card.dart';
import 'widgets/home_banners.dart';

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
  int? _categoryId;
  bool _onlyOpen = false;
  final TextEditingController _search = TextEditingController();
  final _catalogueScroll = ScrollController();
  final _headerKey = GlobalKey();

  @override
  void dispose() {
    _search.dispose();
    _catalogueScroll.dispose();
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

  void _exploreBanner(String kind, List<FoodCategory> categories) {
    final pattern = switch (kind) {
      'pupusas' => RegExp('pupus'),
      'burgers' => RegExp('hamburg|burger|sándwich|sandwich'),
      _ => RegExp('típico|tipico'),
    };
    int? selected;
    for (final category in categories) {
      if (pattern.hasMatch(category.name.toLowerCase())) {
        selected = category.id;
        break;
      }
    }
    _search.clear();
    setState(() {
      _categoryId = selected;
      _onlyOpen = false;
    });
    final height = _headerKey.currentContext?.size?.height;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_catalogueScroll.hasClients) {
        return;
      }
      _catalogueScroll.animateTo(
        (height ?? 0.0).clamp(0.0, _catalogueScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
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
        backgroundColor: _tab == 0
            ? AppTheme.discoveryBackground
            : AppTheme.background,
        appBar: _tab == 1 && widget.onLogout != null
            ? null
            : AppBar(
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor: _tab == 0
                    ? AppTheme.discoveryBackground
                    : AppTheme.background,
                foregroundColor: _tab == 0
                    ? AppTheme.discoveryPaper
                    : AppTheme.navy,
                systemOverlayStyle: _tab == 0
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
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
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: _tab == 0
                    ? states.contains(WidgetState.selected)
                          ? AppTheme.discoveryBackground
                          : AppTheme.discoveryMuted
                    : AppTheme.navy,
              ),
            ),
            labelTextStyle: WidgetStatePropertyAll(
              TextStyle(
                color: _tab == 0 ? AppTheme.discoveryPaper : AppTheme.navy,
                fontSize: 12,
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: _tab == 0
                ? AppTheme.discoveryBackground
                : Theme.of(context).colorScheme.surface,
            indicatorColor: _tab == 0
                ? AppTheme.discoveryAccent
                : AppTheme.tealSoft,
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
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(
          bodyColor: AppTheme.discoveryPaper,
          displayColor: AppTheme.discoveryPaper,
        ),
        scaffoldBackgroundColor: AppTheme.discoveryBackground,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.discoveryAccent,
          onPrimary: AppTheme.discoveryBackground,
          surface: AppTheme.discoveryBackground,
          onSurface: AppTheme.discoveryPaper,
          onSurfaceVariant: AppTheme.discoveryMuted,
          outline: Color(0xFF56717D),
          outlineVariant: Color(0xFF2B4B59),
          surfaceContainerHighest: Color(0xFF204555),
        ),
      ),
      child: FutureBuilder<HomeData>(
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

          final selectedCategory =
              data.categories.any((c) => c.id == _categoryId)
              ? _categoryId
              : null;
          final String query = _search.text.trim().toLowerCase();
          final List<Restaurant> restaurants = data.restaurants
              .where(
                (restaurant) =>
                    restaurant.name.toLowerCase().contains(query) &&
                    (!_onlyOpen || restaurant.isOpen) &&
                    (selectedCategory == null ||
                        restaurant.foodCategories.any(
                          (c) => c.id == selectedCategory,
                        )),
              )
              .toList();
          final int total = restaurants.length;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              controller: _catalogueScroll,
              key: const PageStorageKey<String>('client-home'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              itemCount: (total + 1) ~/ 2 + 3 + (total == 0 ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return _Header(
                    key: _headerKey,
                    onExplore: (kind) => _exploreBanner(kind, data.categories),
                    zone: data.zone!,
                    categories: data.categories,
                    selectedCategory: selectedCategory,
                    onCategory: (id) => setState(() => _categoryId = id),
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
                      _SectionTitle(
                        count: total,
                        onlyOpen: _onlyOpen,
                        onToggle: () => setState(() => _onlyOpen = !_onlyOpen),
                      ),
                    ],
                  );
                }

                if (index == (total + 1) ~/ 2 + 2 + (total == 0 ? 1 : 0)) {
                  return Column(
                    children: [
                      LocalFoodBanner(
                        onExplore: () =>
                            _exploreBanner('tipicos', data.categories),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.favorite_border_rounded,
                              color: AppTheme.discoveryAccent,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Menos vueltas.\nMás de lo que te gusta.',
                                style: TextStyle(
                                  color: AppTheme.discoveryMuted,
                                  fontSize: 12,
                                  height: 1.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                if (total == 0) {
                  return _MessageState(
                    icon: query.isEmpty
                        ? Icons.storefront_outlined
                        : Icons.search_off_rounded,
                    title: query.isEmpty
                        ? selectedCategory == null
                              ? 'No hay restaurantes disponibles'
                              : 'No hay restaurantes en esta categoría'
                        : 'No encontramos ese restaurante',
                    message: query.isEmpty
                        ? selectedCategory == null
                              ? 'Probá actualizar en unos minutos.'
                              : 'Probá otra categoría o elegí Todas.'
                        : 'Probá otro nombre o borrá la búsqueda.',
                    onRetry:
                        query.isEmpty && selectedCategory == null && !_onlyOpen
                        ? _reload
                        : () async {
                            _search.clear();
                            setState(() {
                              _categoryId = null;
                              _onlyOpen = false;
                            });
                          },
                  );
                }
                final first = (index - 2) * 2;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var offset = 0; offset < 2; offset++) ...[
                      if (offset == 1) const SizedBox(width: 14),
                      Expanded(
                        child: first + offset < total
                            ? RestaurantCard(
                                restaurant: restaurants[first + offset],
                                onTap: () => _openRestaurant(
                                  restaurants[first + offset],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
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
            text: 'toro',
            style: TextStyle(color: AppTheme.discoveryPaper),
          ),
          TextSpan(
            text: 'go',
            style: TextStyle(color: AppTheme.yellow),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(color: AppTheme.discoveryAccent),
          ),
        ],
      ),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.8,
        fontSize: 29,
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
    required this.categories,
    required this.selectedCategory,
    required this.onCategory,
    required this.onExplore,
    super.key,
  });
  final DeliveryZone zone;
  final List<FoodCategory> categories;
  final int? selectedCategory;
  final ValueChanged<int?> onCategory;
  final TextEditingController search;
  final VoidCallback onSearch;
  final ValueChanged<String> onExplore;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.place_outlined,
              color: AppTheme.discoveryAccent,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'ENTREGAMOS EN',
                    style: text.bodySmall?.copyWith(
                      color: AppTheme.discoveryMuted,
                      fontSize: 11,
                      letterSpacing: 1.3,
                    ),
                  ),
                  Text(
                    zone.name,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Tarifas de entrega',
              icon: const Icon(
                Icons.info_outline_rounded,
                color: AppTheme.discoveryMuted,
              ),
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
        const SizedBox(height: AppSpacing.lg),
        const _DiscoveryIntro(),
        const SizedBox(height: AppSpacing.lg),
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
        if (categories.isNotEmpty) ...[
          Text('Categorías', style: text.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CategoryTile(
                  key: const ValueKey('home-category-all'),
                  category: const FoodCategory(
                    id: 0,
                    name: 'Todas',
                    iconKey: 'all',
                  ),
                  selected: selectedCategory == null,
                  onTap: () => onCategory(null),
                ),
                for (final category in categories)
                  _CategoryTile(
                    key: ValueKey('home-category-${category.id}'),
                    category: category,
                    selected: selectedCategory == category.id,
                    onTap: () => onCategory(category.id),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        HomePromoSlider(onExplore: onExplore),
      ],
    );
  }
}

class _DiscoveryIntro extends StatelessWidget {
  const _DiscoveryIntro();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned(
        right: 8,
        top: 10,
        child: _IntroDoodle(
          icon: Icons.local_pizza_outlined,
          angle: .3,
          size: 42,
        ),
      ),
      const Positioned(
        right: 66,
        top: 75,
        child: _IntroDoodle(
          icon: Icons.lunch_dining_outlined,
          angle: -.25,
          size: 45,
        ),
      ),
      const Positioned(
        right: 110,
        top: 2,
        child: _IntroDoodle(
          icon: Icons.restaurant_outlined,
          angle: -.4,
          size: 28,
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿QUÉ SE TE ANTOJA HOY?',
            style: TextStyle(
              color: AppTheme.discoveryMuted,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 13),
          const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Hoy se come\n'),
                TextSpan(
                  text: 'bien rico.',
                  style: TextStyle(color: AppTheme.discoveryAccent),
                ),
              ],
            ),
            style: TextStyle(
              color: AppTheme.discoveryPaper,
              fontSize: 40,
              height: 1.04,
              letterSpacing: -1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 15),
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Elegí cerca. Disfrutá en casa.',
                  style: TextStyle(
                    color: AppTheme.discoveryMuted,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(Icons.north_east, color: AppTheme.yellow, size: 26),
            ],
          ),
        ],
      ),
    ],
  );
}

class _IntroDoodle extends StatelessWidget {
  const _IntroDoodle({
    required this.icon,
    required this.angle,
    required this.size,
  });
  final IconData icon;
  final double angle;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Transform.rotate(
      angle: angle,
      child: Icon(
        icon,
        size: size,
        color: AppTheme.discoveryMuted.withValues(alpha: .12),
      ),
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
    super.key,
  });
  final FoodCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.zero,
    child: Semantics(
      button: true,
      selected: selected,
      label: category.name,
      excludeSemantics: true,
      child: Tooltip(
        message: category.name,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.image),
            child: SizedBox(
              width: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.yellow
                            : const Color(0xFF183A49),
                        borderRadius: BorderRadius.circular(AppRadius.image),
                      ),
                      child: FoodCategoryIcon(
                        category: category,
                        size: category.iconUrl == null ? 24 : 36,
                        color: selected
                            ? AppTheme.discoveryBackground
                            : AppTheme.discoveryMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected
                            ? AppTheme.yellow
                            : AppTheme.discoveryMuted,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Titulo de seccion con el conteo, como en las referencias.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.count,
    required this.onlyOpen,
    required this.onToggle,
  });

  final int count;
  final bool onlyOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Por aquí cerca',
                style: text.titleMedium?.copyWith(
                  color: AppTheme.discoveryPaper,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count restaurantes',
                style: text.bodySmall?.copyWith(
                  color: AppTheme.discoveryMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilterChip(
          label: const Text('Abiertos'),
          selected: onlyOpen,
          onSelected: (_) => onToggle(),
          selectedColor: const Color(0xFF204555),
          backgroundColor: AppTheme.discoveryBackground,
          labelStyle: const TextStyle(
            color: AppTheme.discoveryPaper,
            fontSize: 11,
          ),
          checkmarkColor: AppTheme.discoveryAccent,
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
                  color: colors.onSurface,
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
