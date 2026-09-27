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
    this.needsSettings = false,
  });

  final double latitude;
  final double longitude;

  /// true = la dijo el telefono. false = es la de respaldo.
  final bool isReal;

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

  /// Pide la ubicacion, con el permiso y todo.
  ///
  /// NUNCA lanza. Devuelve [fallback] si el permiso esta negado, si el GPS esta
  /// apagado, si tarda demasiado, o si el navegador no la da.
  ///
  /// Es a proposito: una app de delivery que no abre porque no consiguio el GPS
  /// es peor que una que muestra la zona de siempre y lo avisa.
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

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // Sin limite de tiempo, en un lugar con mala senal la pantalla se
          // queda esperando para siempre.
          timeLimit: Duration(seconds: 10),
        ),
      );

      return Place(
        latitude: position.latitude,
        longitude: position.longitude,
        isReal: true,
      );
    } catch (_) {
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
}
