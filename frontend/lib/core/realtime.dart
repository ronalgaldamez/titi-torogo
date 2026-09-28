import 'dart:async';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'auth_storage.dart';

/// El tiempo real: el WebSocket (Reverb) que avisa cuando un pedido cambia.
///
/// PARA QUE SIRVE ESTE ARCHIVO
///
/// Para que NINGUNA pantalla sepa que hay un WebSocket abajo. La pantalla pide
/// "avisame de este pedido" y recibe un stream; si el tiempo real no esta
/// disponible —el celular en datos sin `adb reverse`, la PC apagada, el puerto
/// 8081 sin publicar— el stream simplemente no emite nada y la pantalla sigue
/// funcionando como funcionaba antes.
///
/// Eso es a proposito y no es un descuido: el seguimiento del pedido NO puede
/// depender de un canal extra. El tiempo real es una MEJORA; el boton de
/// actualizar y el deslizar para refrescar siguen siendo la base.
///
/// POR QUE UNA SOLA INSTANCIA
///
/// Si cada pantalla abriera su propio WebSocket, con tres pantallas abiertas
/// habria tres conexiones y tres autorizaciones para el mismo dato.
class Realtime {
  Realtime._();

  static final Realtime instance = Realtime._();

  /// A donde se conecta.
  ///
  /// Se pasa al compilar, igual que la API:
  ///
  ///   Telefono (con adb reverse tcp:8081 tcp:8081)
  ///     -> el default sirve: ws://localhost:8081
  ///
  ///   Telefono por wifi, sin cable
  ///     flutter run --dart-define=REVERB_WS_URL=ws://192.168.1.7:8081
  ///
  /// El 8081 y no el 8080 porque el 8080 ya es de Nginx (la API).
  static const String wsUrl = String.fromEnvironment(
    'REVERB_WS_URL',
    defaultValue: 'ws://localhost:8081',
  );

  /// La llave publica de Reverb.
  ///
  /// NO es un secreto y por eso puede vivir en la app: viaja en la URL del
  /// WebSocket en cualquier cliente. Lo que protege de verdad los pedidos es
  /// `/api/broadcasting/auth`, que exige el token de la sesion y decide si este
  /// usuario puede escuchar ESTE pedido.
  static const String _appKey = String.fromEnvironment(
    'REVERB_APP_KEY',
    defaultValue: 'k4csnusogqvx7ufeu7il',
  );

  /// El nombre del evento.
  ///
  /// Tiene que ser IDENTICO al `broadcastAs()` del backend (ver
  /// backend/app/Events/OrderUpdated.php). Si uno de los dos cambia y el otro
  /// no, el telefono queda suscrito a un evento que nunca llega, y no da ningun
  /// error: simplemente se queda mudo. Es el error mas facil de cometer aca.
  static const String _orderEvent = 'order.updated';

  /// El evento con el que Reverb avisa que NO dejo entrar al canal.
  static const String _subscriptionErrorEvent = 'pusher:subscription_error';

  PusherChannelsClient? _client;

  StreamSubscription<void>? _resubscribe;
  StreamSubscription<bool>? _lifecycle;

  /// Lo que se le avisa a la pantalla: "hay tiempo real" o "no hay".
  final StreamController<bool> _connected = StreamController<bool>.broadcast();

  bool _isConnected = false;

  /// Las escuchas abiertas AHORA, para volver a suscribirlas cuando la
  /// conexion se cae y vuelve.
  ///
  /// Sin esto, despues de un corte de red (el motorizado pasa por una zona sin
  /// senal, el wifi parpadea) la pantalla se quedaria muda para siempre hasta
  /// que el cliente la cierre y la vuelva a abrir.
  final Set<RealtimeWatch> _open = <RealtimeWatch>{};

  /// ¿Hay conexion con Reverb en este momento?
  ///
  /// Existe ademas del stream porque un stream de broadcast NO repite el
  /// ultimo valor: una pantalla que se abre despues de que la conexion se
  /// establecio no recibiria nada y creeria que no hay tiempo real.
  bool get isConnected => _isConnected;

  /// Avisa cada vez que el tiempo real se prende o se apaga.
  Stream<bool> get connected => _connected.stream;

  /// Empieza a escuchar UN pedido.
  ///
  /// Lo que devuelve hay que cerrarlo cuando la pantalla se va (ver
  /// [RealtimeWatch.close]). Si no se cerrara, la app seguiria recibiendo
  /// eventos de pedidos que ya nadie esta mirando.
  Future<RealtimeWatch> watchOrder(int orderId) {
    return _watch('private-orders.$orderId');
  }

  /// Empieza a escuchar TODO lo de un restaurante: los pedidos que entran y los
  /// que se mueven.
  ///
  /// El restaurante no puede usar [watchOrder] aunque quisiera: no sabe los
  /// numeros de pedido de antemano, y el que acaba de entrar es justamente el
  /// que todavia no conoce.
  Future<RealtimeWatch> watchRestaurant(int restaurantId) {
    return _watch('private-restaurants.$restaurantId');
  }

  /// Abre un canal privado y devuelve la escucha.
  ///
  /// El nombre va COMPLETO, con el prefijo 'private-'.
  ///
  /// El paquete NO lo agrega solo: si le pasamos 'orders.7', se suscribe a un
  /// canal que no existe y no llega nada, sin ningun error. Lo verifique en la
  /// fuente del paquete (private_channel.dart usa el nombre tal cual).
  Future<RealtimeWatch> _watch(String channelName) async {
    final PusherChannelsClient client = await _clientOrConnect();

    final PrivateChannel channel = client.privateChannel(
      channelName,
      authorizationDelegate:
          EndpointAuthorizableChannelTokenAuthorizationDelegate
              .forPrivateChannel(
        authorizationEndpoint: Uri.parse(
          '${ApiClient.baseUrl}/broadcasting/auth',
        ),
        // El token se lee en cada canal nuevo, no se guarda: si la sesion se
        // renovo, la autorizacion tiene que ir con el token de ahora.
        headers: <String, String>{
          'Accept': 'application/json',
          'Authorization': 'Bearer ${await _token()}',
        },
      ),
    );

    final StreamController<Map<String, dynamic>> messages =
        StreamController<Map<String, dynamic>>();

    final StreamSubscription<ChannelReadEvent> events =
        channel.bind(_orderEvent).listen((ChannelReadEvent event) {
      // tryGetDataAsMap deserializa el 'data' del evento, que es el JSON que
      // armo el backend: {order: {...}, previous_status: 'ready'}.
      final Map<String, dynamic>? payload = event.tryGetDataAsMap();

      if (payload != null) {
        messages.add(payload);
      }
    });

    final StreamSubscription<ChannelReadEvent> failures =
        channel.bind(_subscriptionErrorEvent).listen((ChannelReadEvent event) {
      // Esto es lo que se ve cuando la autorizacion falla (401/403): el canal
      // NO se abre y los eventos no llegan NUNCA. Se deja escrito en la consola
      // porque, sin esto, el sintoma es "no pasa nada" y no hay por donde
      // empezar a buscar.
      debugPrint('Tiempo real: Reverb no dejo entrar al canal ($event)');
    });

    final RealtimeWatch watch = RealtimeWatch._(
      channel: channel,
      messagesController: messages,
      events: events,
      failures: failures,
    );

    _open.add(watch);

    // Si ya hay conexion, esto lo suscribe ahora mismo. Si todavia no, el
    // listener de onConnectionEstablished lo hace cuando entre.
    channel.subscribeIfNotUnsubscribed();

    return watch;
  }

  /// Cierra una escucha y suelta el canal.
  Future<void> _close(RealtimeWatch watch) async {
    _open.remove(watch);

    // Si OTRA pantalla esta mirando el mismo canal, se deja abierto.
    //
    // Por que: el paquete devuelve la MISMA instancia de canal para el mismo
    // nombre, asi que dar de baja el canal desde una pantalla dejaria muda a la
    // otra sin ningun error. Solo se da de baja cuando ya no queda nadie.
    final bool stillWatched =
        _open.any((RealtimeWatch other) => other.channel == watch.channel);

    if (!stillWatched) {
      // unsubscribe le avisa al servidor que ya no lo queremos. Cancelar el
      // stream solo deja de escuchar en el telefono: el canal quedaria abierto
      // alla y el backend seguiria mandando eventos a nadie.
      watch.channel.unsubscribe();
    }

    await watch.events.cancel();
    await watch.failures.cancel();

    // Se cierra el CONTROLLER, no el stream: `Stream` no tiene close(), el que
    // se cierra es el que lo alimenta. Si no se cerrara, la pantalla que se fue
    // dejaria el controller abierto esperando eventos que ya nadie lee.
    await watch.messagesController.close();
  }

  /// El cliente de Reverb, conectado una sola vez.
  Future<PusherChannelsClient> _clientOrConnect() async {
    final PusherChannelsClient? existing = _client;

    if (existing != null && !existing.isDisposed) {
      return existing;
    }

    // Si se esta armando un cliente NUEVO (el anterior se cerro), los listeners
    // del viejo se sueltan primero. Si quedaran vivos, el estado de conexion se
    // actualizaria desde dos clientes a la vez y la chapita "En vivo" diria
    // cualquier cosa.
    await _resubscribe?.cancel();
    await _lifecycle?.cancel();

    final Uri uri = Uri.parse(wsUrl);

    final PusherChannelsClient client = PusherChannelsClient.websocket(
      options: PusherChannelsOptions.fromHost(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.port,
        key: _appKey,
      ),
      // El paquete pide reconectarse llamando a refresh(). Se le dice que si,
      // siempre.
      //
      // NO se le avisa nada al cliente: un pedido que se actualiza unos
      // segundos tarde no es un problema, y un cartel de error por eso seria
      // peor que el problema. Cuando no hay tiempo real, la pantalla sigue
      // andando con el boton de actualizar.
      connectionErrorHandler: (exception, trace, refresh) {
        debugPrint('Tiempo real: se corto la conexion ($exception)');
        refresh();
      },
    );

    // Cada vez que la conexion se establece —la primera vez y en cada
    // reconexion— se vuelven a suscribir los canales abiertos.
    _resubscribe = client.onConnectionEstablished.listen((_) {
      for (final RealtimeWatch watch in _open) {
        watch.channel.subscribeIfNotUnsubscribed();
      }
    });

    _lifecycle = client.lifecycleStream
        .map((PusherChannelsClientLifeCycleState state) =>
            state == PusherChannelsClientLifeCycleState.establishedConnection)
        .distinct()
        .listen((bool connected) {
      _isConnected = connected;
      _connected.add(connected);
    });

    _client = client;

    // connect() devuelve un Future que se completa cuando la conexion se
    // establece; NO se espera aca a proposito. Si Reverb no contesta, esperarlo
    // dejaria a la pantalla cargando para siempre por un extra que es opcional.
    unawaited(client.connect());

    return client;
  }

  Future<String> _token() async {
    final String? token = await AuthStorage().readToken();

    // Vacio y no una excepcion: sin token el canal no se autoriza, no llega
    // ningun evento, y la pantalla sigue igual con su boton de actualizar.
    return token ?? '';
  }
}

/// Una escucha abierta de un canal de tiempo real.
///
/// Se cierra con [close] cuando la pantalla que la abrio se va.
class RealtimeWatch {
  RealtimeWatch._({
    required this.channel,
    required this.messagesController,
    required this.events,
    required this.failures,
  });

  /// El canal de Reverb. Lo usa [Realtime] para volver a suscribirlo cuando la
  /// conexion se recupera.
  final PrivateChannel channel;

  final StreamSubscription<ChannelReadEvent> events;
  final StreamSubscription<ChannelReadEvent> failures;

  /// El que alimenta [messages].
  ///
  /// Es publico y no privado por una razon concreta: al cerrar la escucha hay
  /// que cerrar ESTO (el stream en si no tiene close), y quien cierra es
  /// [Realtime].
  final StreamController<Map<String, dynamic>> messagesController;

  /// Los avisos del backend para este pedido.
  ///
  /// Cada aviso es el payload tal cual lo mando Laravel. La pantalla decide que
  /// hacer con el: hoy adentro viene `order` (el pedido completo) y
  /// `previous_status`.
  Stream<Map<String, dynamic>> get messages => messagesController.stream;

  /// Cierra la escucha. La pantalla lo llama en su dispose().
  Future<void> close() => Realtime.instance._close(this);
}
