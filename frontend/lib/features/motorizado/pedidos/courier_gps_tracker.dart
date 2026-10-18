import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api_client.dart';
import 'courier_order_repository.dart';

/// Comparte únicamente posiciones nuevas del GPS mientras hay entregas propias.
class CourierGpsTracker extends ChangeNotifier {
  CourierGpsTracker({
    required this.repository,
    required this.onAssignmentsChanged,
    Future<Stream<Position>> Function(bool ask)? positionSource,
  }) : positionSource = positionSource ?? _positions;

  final Future<CourierOrderRepository> Function() repository;
  final VoidCallback onAssignmentsChanged;
  final Future<Stream<Position>> Function(bool ask) positionSource;
  Set<int> _orders = {};
  StreamSubscription<Position>? _subscription;
  Timer? _timer;
  Position? _latest;
  DateTime? _lastAttempt;
  bool _starting = false;
  bool _sending = false;
  bool _disposed = false;
  int _generation = 0;
  String message =
      'Activá el GPS para compartir tu ubicación durante la entrega.';
  bool get running => _subscription != null;

  void setOrders(Set<int> ids) {
    _orders = {...ids};
    if (ids.isEmpty) {
      _stop();
    }
  }

  Future<void> start({bool ask = false}) async {
    if (_disposed || _starting || running || _orders.isEmpty) {
      return;
    }
    _starting = true;
    final generation = _generation;
    try {
      final stream = await positionSource(ask);
      if (_disposed || generation != _generation || _orders.isEmpty) {
        return;
      }
      _subscription = stream.listen(
        (position) {
          final age = DateTime.now().difference(position.timestamp);
          if (!position.latitude.isFinite ||
              !position.longitude.isFinite ||
              !position.accuracy.isFinite ||
              position.accuracy < 0 ||
              position.accuracy > 100 ||
              age > const Duration(seconds: 30) ||
              age < const Duration(seconds: -10)) {
            _message('Esperando una posición GPS reciente y precisa.');
            return;
          }
          _latest = position;
          if (_lastAttempt == null ||
              DateTime.now().difference(_lastAttempt!) >=
                  const Duration(seconds: 10)) {
            unawaited(_send());
          }
        },
        onError: (Object error) {
          _stop();
          _message('GPS interrumpido. Revisá el permiso y activalo otra vez.');
        },
        onDone: () {
          _stop();
          _message('GPS detenido. Activá el seguimiento para continuar.');
        },
      );
      _timer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => unawaited(_send()),
      );
      _message('Esperando la ubicación del GPS…');
    } on Exception catch (error) {
      if (!_disposed && generation == _generation) {
        _message(
          error is ApiException
              ? error.message
              : 'No pudimos iniciar el GPS. Revisá sus permisos.',
        );
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _send() async {
    if (_disposed || _sending || _orders.isEmpty) {
      return;
    }
    _sending = true;
    _lastAttempt = DateTime.now();
    final generation = _generation;
    try {
      final api = await repository();
      final mine = await api.loadMine();
      if (_disposed || generation != _generation) {
        return;
      }
      final ids = mine
          .where((o) => o.status == 'ready' || o.status == 'picked_up')
          .map((o) => o.id)
          .toSet();
      if (!setEquals(ids, _orders)) {
        _orders = ids;
        onAssignmentsChanged();
      }
      if (_orders.isEmpty) {
        _stop();
        return;
      }
      final position = _latest;
      if (position == null ||
          DateTime.now().difference(position.timestamp) >
              const Duration(seconds: 30)) {
        _message('Esperando una posición GPS reciente y precisa.');
        return;
      }
      for (final id in {..._orders}) {
        if (_disposed || generation != _generation || !_orders.contains(id)) {
          return;
        }
        try {
          await api.sendLocation(
            id,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            capturedAt: position.timestamp,
          );
        } on ApiException catch (error) {
          if (error.statusCode == 404 || error.statusCode == 409) {
            _orders.remove(id);
            onAssignmentsChanged();
            continue;
          }
          rethrow;
        }
      }
      if (_disposed || generation != _generation) {
        return;
      }
      if (_orders.isEmpty) {
        _stop();
      } else {
        _message('GPS activo · Compartiendo ubicación durante tus entregas.');
      }
    } on ApiException catch (error) {
      if (_disposed || generation != _generation) {
        return;
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        _orders.clear();
        _stop();
        _message('GPS detenido. Volvé a iniciar sesión para continuar.');
      } else {
        _message(
          error.statusCode == 422
              ? error.message
              : 'No pudimos actualizar el GPS. Reintentaremos sin guardar recorridos.',
        );
      }
    } finally {
      _sending = false;
    }
  }

  void _message(String value) {
    if (_disposed) {
      return;
    }
    message = value;
    notifyListeners();
  }

  void _stop() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    final previous = _subscription;
    _subscription = null;
    unawaited(previous?.cancel());
    _latest = null;
    _lastAttempt = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _orders.clear();
    _stop();
    super.dispose();
  }

  static Future<Stream<Position>> _positions(bool ask) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (ask) {
        await Geolocator.openLocationSettings();
      }
      throw ApiException(
        'Encendé la ubicación del teléfono para compartir tu GPS.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && ask) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (ask) {
        await Geolocator.openAppSettings();
      }
      throw ApiException('Permití la ubicación en los ajustes de Toro Go.');
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw ApiException(
        'Activá el seguimiento y concedé el permiso de ubicación.',
      );
    }
    final LocationSettings settings =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 10),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Toro Go · Entrega en curso',
              notificationText:
                  'Compartiendo tu ubicación con el cliente. Se detiene al finalizar tus entregas.',
              notificationChannelName: 'Seguimiento de entregas',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          );
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}
