import 'package:geolocator/geolocator.dart';

enum LocationAccess {
  granted,
  denied,

  /// The user chose "Don't ask again"; only Settings can change it.
  deniedForever,
}

/// "While using the app" location permission. Background location is only
/// requested when a ride starts (Prompt 10), never here.
abstract interface class LocationPermissionService {
  Future<LocationAccess> current();
  Future<LocationAccess> requestWhileInUse();
  Future<bool> openSettings();
}

class GeolocatorPermissionService implements LocationPermissionService {
  const GeolocatorPermissionService();

  static LocationAccess _map(LocationPermission p) => switch (p) {
    LocationPermission.always ||
    LocationPermission.whileInUse => LocationAccess.granted,
    LocationPermission.deniedForever => LocationAccess.deniedForever,
    LocationPermission.denied ||
    LocationPermission.unableToDetermine => LocationAccess.denied,
  };

  @override
  Future<LocationAccess> current() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<LocationAccess> requestWhileInUse() async {
    final now = await Geolocator.checkPermission();
    if (now == LocationPermission.deniedForever) {
      return LocationAccess.deniedForever;
    }
    if (now == LocationPermission.whileInUse ||
        now == LocationPermission.always) {
      return LocationAccess.granted;
    }
    return _map(await Geolocator.requestPermission());
  }

  @override
  Future<bool> openSettings() => Geolocator.openAppSettings();
}
