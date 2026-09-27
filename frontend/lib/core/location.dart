import 'package:geolocator/geolocator.dart';

/// Donde esta una persona, con una marca de si es de verdad y de por que no.
///
/// La marca importa: si el cliente no dio permiso, la app sigue andando con una
/// ubicacion de respaldo, pero la pantalla tiene que PODER decir que esta
/// mostrando otra cosa. Sin esa marca, la app mentiria sin darse cuenta.
class Place {
  const Place({
    required this.latitude,
    required this.longitude,
    required this.isReal,
    this.accuracyMeters,
    this.needsSettings = false,
  });

  /// A partir de cuantos metros de error una ubicacion ya no sirve para
  /// guardar una direccion.
  ///
  /// 100 metros es mas o menos una cuadra. Con mas error que eso, el motorizado
  /// puede terminar en otra colonia — que es justo lo que este archivo y el
  /// formulario de direcciones intentan evitar.
  static const double preciseMeters = 100;

  final double latitude;
  final double longitude;

  /// true = la dijo el telefono. false = es la de respaldo.
  final bool isReal;

  /// Cuanto error admite el telefono, en metros. null = no lo dijo.
  ///
  /// El telefono NO devuelve un punto exacto: devuelve un punto con un radio de
  /// error. Ese radio es la diferencia entre "estas en tu casa" y "estas en
  /// algun lugar del municipio".
  final double? accuracyMeters;

  /// true = la dijo el telefono, pero con poca precision: puede caer a varias
  /// cuadras.
  ///
  /// Alcanza para saber en que ZONA esta la persona (el Home), pero no para
  /// guardar una direccion. Ver address_form_screen.dart.
  ///
  /// Si el telefono no dijo el error, se deja pasar: eso pasa con las
  /// direcciones ya guardadas, que traen coordenadas propias y no una medida
  /// nueva del GPS. Marcarlas como aproximadas trabaria la edicion de una
  /// direccion que el cliente ya tenia bien.
  bool get isApproximate =>
      isReal && accuracyMeters != null && accuracyMeters! > preciseMeters;

  /// El error, redondeado y listo para meter en un texto. Ejemplo: "±120 m".
  ///
  /// Esta aca y no en cada pantalla para que las dos digan lo mismo: si un dia
  /// se redondea distinto, se cambia en un solo lugar.
  String get accuracyText => '±${accuracyMeters?.round() ?? 0} m';

  /// true = el permiso esta negado PARA SIEMPRE.
  ///
  /// Es distinto de "negado a secas". Cuando el usuario lo niega una vez,
  /// Android todavia muestra el cartel y alcanza con volver a pedirlo. Pero si
  /// lo nego desde los Ajustes del telefono, el sistema YA NO PREGUNTA MAS: la
  /// unica salida es mandarlo a esos Ajustes.
  ///
  /// Sin esta distincion, el boton de "Actualizar ubicacion" no hace nada y el
  /// cliente se queda trabado sin entender por que.
  final bool needsSettings;
}

/// La ubicacion del telefono.
///
/// Se usa en el Home del cliente y en la app del motorizado: las dos necesitan
/// saber DONDE ESTA la persona para poder preguntarle al backend que hay cerca.
class LocationService {
  /// Ubicacion de respaldo: el Mall del Sol.
  ///
  /// OJO, PORQUE ESTO CONFUNDE: el Mall del Sol **NO es Tejutla centro**. El
  /// pueblo de Tejutla esta a unos 9 km de ahi. El Mall es un punto que cae
  /// DENTRO del poligono que delimita la zona donde la app opera.
  ///
  /// Por eso en ningun texto de la app se dice "la ubicacion de Tejutla": se
  /// dice el Mall del Sol, que es el punto de verdad. Decir Tejutla mandaria a
  /// la gente a otro lado.
  ///
  /// Esta dentro de la zona a proposito: si el cliente no da permiso de
  /// ubicacion, el Home tiene que seguir siendo usable — mostrando los
  /// restaurantes de la zona con un aviso, en vez de una pantalla vacia o un
  /// error.
  ///
  /// OJO: esto NO se usa para guardar direcciones. Una direccion con estas
  /// coordenadas quedaria ubicada en el Mall, y el motorizado iria a otro lado.
  /// El formulario de direcciones no deja guardar sin una ubicacion REAL, por
  /// esa misma razon.
  /// Las coordenadas del Mall del Sol, en UN solo lugar.
  ///
  /// Se repiten en [fallback] y en [_blockedForever] a traves de estas dos
  /// constantes, para que no puedan quedar en puntos distintos.
  static const double _mallLatitude = 14.101203787387021;
  static const double _mallLongitude = -89.15061654556241;

  static const Place fallback = Place(
    latitude: _mallLatitude,
    longitude: _mallLongitude,
    isReal: false,
  );

  /// Lo mismo que [fallback], pero marcando que el permiso quedo negado para
  /// siempre.
  ///
  /// Es una constante aparte y no `const Place(latitude: fallback.latitude...)`
  /// porque Dart NO DEJA leer una propiedad dentro de una expresion const, ni
  /// siquiera si el objeto es const. Ahi el compilador no puede resolverlo.
  static const Place _blockedForever = Place(
    latitude: _mallLatitude,
    longitude: _mallLongitude,
    isReal: false,
    needsSettings: true,
  );

  /// Los dos intentos de conseguir el punto, en orden.
  ///
  /// Primero se pide precision alta, que es la de los satelites. Si eso no
  /// llega —bajo techo, entre edificios, con el cielo tapado—, se pide la
  /// ubicacion "que haya": la de la antena o la del wifi.
  static const List<LocationSettings> _attempts = <LocationSettings>[
    LocationSettings(
      accuracy: LocationAccuracy.high,
      // El limite de tiempo es lo que evita que la pantalla se quede esperando
      // para siempre cuando no hay senal.
      timeLimit: Duration(seconds: 10),
    ),
    LocationSettings(
      accuracy: LocationAccuracy.low,
      // El segundo intento es mas corto a proposito: si tampoco contesta, es
      // que no hay con que, y hacer esperar al cliente 18 segundos para decirle
      // lo mismo no sirve.
      timeLimit: Duration(seconds: 8),
    ),
  ];

  /// Pide la ubicacion, con el permiso y todo.
  ///
  /// NO lanza por las causas normales: permiso negado, GPS apagado, el telefono
  /// que no contesta a tiempo o el navegador que dijo que no. En todos esos
  /// casos devuelve [fallback].
  ///
  /// Es a proposito: una app de delivery que no abre porque no consiguio el GPS
  /// es peor que una que muestra la zona de siempre y lo avisa.
  ///
  /// Lo que SI se deja pasar es un error de programacion (un tipo que no era,
  /// un null donde no va). Tragarse eso esconde la pantalla en blanco y nadie
  /// se entera de que hay un bug: por eso el catch es de [Exception] y no de
  /// cualquier cosa.
  ///
  /// [ask] = false NO muestra el cartel del permiso: solo mira como esta.
  ///
  /// El formulario de direcciones lo usa asi AL ABRIR. Si abris la pantalla y la
  /// app te pide el permiso de una — cuando lo acabás de negar dos segundos
  /// antes — es molesto, y encima el cartel pausa la app y enturbia todo. Mejor
  /// mostrar el estado y dejar que el cliente toque "Actualizar ubicación" si
  /// quiere que le pregunte.
  Future<Place> current({bool ask = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return fallback;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      // Solo se pide si todavia no dijo nada. Si ya dijo que no, volver a
      // preguntar en cada carga es molesto y algunos navegadores lo bloquean.
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }

      // Negado para siempre: Android ya no va a mostrar el cartel. Se avisa
      // para que la pantalla ofrezca abrir los Ajustes, que es la unica salida.
      if (permission == LocationPermission.deniedForever) {
        return _blockedForever;
      }

      if (permission == LocationPermission.denied) {
        return fallback;
      }

      final Position? position = await _position();

      if (position == null) {
        return fallback;
      }

      return Place(
        latitude: position.latitude,
        longitude: position.longitude,
        isReal: true,
        // El error que el telefono admite. Va guardado para que la pantalla
        // pueda decir "aproximada" y para que el formulario de direcciones
        // sepa si ese punto sirve para mandar un motorizado.
        accuracyMeters: position.accuracy,
      );
    } on Exception {
      // GPS apagado, permiso negado, tiempo agotado, o el navegador dijo que
      // no: en cualquiera de esos casos se sigue con la de respaldo.
      return fallback;
    }
  }

  /// Abre los Ajustes de la app en el telefono, para que el cliente prenda el
  /// permiso de ubicacion a mano.
  ///
  /// Es la unica salida cuando el permiso quedo negado para siempre.
  Future<void> openSettings() {
    return Geolocator.openAppSettings();
  }

  /// Los intentos de [_attempts], uno atras del otro. null = ninguno sirvio.
  ///
  /// ACA ESTABA EL PROBLEMA QUE APARECIO PROBANDO: parado adentro de la casa,
  /// el pedido de precision alta se vence, y la app se quedaba con el Mall del
  /// Sol — a 9 km de la casa del cliente. El cliente veia "estamos usando el
  /// Mall del Sol como referencia" sin entender por que, si el permiso estaba
  /// dado y el GPS prendido.
  ///
  /// El segundo intento devuelve un punto de verdad, de la persona, aunque sea
  /// con error de cuadras. Viene marcado como aproximado en [Place], asi que
  /// nadie lo confunde con una medida buena.
  Future<Position?> _position() async {
    for (final LocationSettings settings in _attempts) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: settings,
        );
      } on Exception {
        // Se prueba con el siguiente intento. Si no hay siguiente, el que
        // llama decide que hacer con el null.
      }
    }

    return null;
  }
}
