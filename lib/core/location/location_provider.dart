import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import 'location_permission.dart';
import 'position_source.dart';
import 'speed.dart' as speed;

enum LocationStatus {
  /// Not checked yet.
  checking,

  /// Permission granted and the phone's location is on.
  on,

  /// Permission not granted; asking again is allowed.
  denied,

  /// "Don't ask again"; only app Settings can change it.
  deniedForever,

  /// Permission granted but the phone's location setting is off.
  serviceOff,
}

/// App-wide rider position and speed. Call [start] when a screen needs
/// location; it re-checks when the app returns from Settings.
class LocationProvider extends ChangeNotifier {
  LocationProvider({
    required LocationPermissionService permissions,
    required PositionSource positions,
  }) : _permissions = permissions,
       _positions = positions;

  final LocationPermissionService _permissions;
  final PositionSource _positions;

  StreamSubscription<RiderFix>? _subscription;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;

  LocationStatus _status = LocationStatus.checking;
  LatLng? _position;
  double _speedKmh = 0;

  LocationStatus get status => _status;

  /// Latest known position, or null before the first fix.
  LatLng? get position => _position;

  double get speedKmh => _speedKmh;

  /// Faster than 10 km/h: typing and posting are disabled.
  bool get isMoving => speed.isMovingAt(_speedKmh);

  /// Location is usable (permission, phone setting, and a fix).
  bool get hasFix => _status == LocationStatus.on && _position != null;

  /// Starts listening if allowed. Safe to call more than once.
  Future<void> start() async {
    _lifecycle ??= AppLifecycleListener(onResume: refresh);
    if (_subscription == null) await refresh();
  }

  /// Re-reads permission and the phone setting, then listens if both allow.
  Future<void> refresh() async {
    final access = await _permissions.current();
    if (_disposed) return;
    switch (access) {
      case LocationAccess.denied:
        return _stop(LocationStatus.denied);
      case LocationAccess.deniedForever:
        return _stop(LocationStatus.deniedForever);
      case LocationAccess.granted:
        if (!await _positions.serviceEnabled()) {
          return _stop(LocationStatus.serviceOff);
        }
    }
    if (_disposed) return;
    _set(LocationStatus.on);
    if (_subscription != null) return;

    _subscription = _positions
        .fixes(background: _background)
        .listen(
          _onFix,
          onError: (Object _) => _stop(LocationStatus.serviceOff),
        );
    if (_position == null) {
      final last = await _positions.lastKnown();
      if (last != null && _position == null && !_disposed) _onFix(last);
    }
  }

  bool _background = false;

  /// During a ride: keep tracking while another app is in front (Android
  /// foreground service with a notification). Restarts the stream.
  Future<void> setBackground(bool on) async {
    if (_background == on) return;
    _background = on;
    await _subscription?.cancel();
    _subscription = null;
    await refresh();
  }

  /// The banner's button: asks for permission, or opens the right settings
  /// page when asking is no longer possible.
  Future<void> fix() async {
    switch (_status) {
      case LocationStatus.denied:
        await _permissions.requestWhileInUse();
        await refresh();
      case LocationStatus.deniedForever:
        await _permissions.openSettings();
      case LocationStatus.serviceOff:
        await _positions.openLocationSettings();
      case LocationStatus.checking:
      case LocationStatus.on:
        await refresh();
    }
  }

  void _onFix(RiderFix fix) {
    _position = fix.point;
    _speedKmh = speed.speedKmh(fix.speedMps);
    notifyListeners();
  }

  void _stop(LocationStatus status) {
    _subscription?.cancel();
    _subscription = null;
    _speedKmh = 0;
    _set(status);
  }

  void _set(LocationStatus status) {
    if (_status == status || _disposed) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}
