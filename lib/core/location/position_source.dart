import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// One GPS reading.
class RiderFix {
  const RiderFix({required this.point, this.speedMps = 0});

  final LatLng point;

  /// Ground speed in m/s; 0 when the device doesn't report it.
  final double speedMps;
}

/// Device location, behind an interface so tests can feed fixes.
abstract interface class PositionSource {
  /// Whether the phone's location setting (GPS) is on.
  Future<bool> serviceEnabled();

  /// Last cached fix, for a fast first paint. May be null.
  Future<RiderFix?> lastKnown();

  /// Live fixes. Errors if location is turned off while listening.
  Stream<RiderFix> fixes();

  Future<bool> openLocationSettings();
}

class GeolocatorPositionSource implements PositionSource {
  const GeolocatorPositionSource();

  static RiderFix _fix(Position p) =>
      RiderFix(point: LatLng(p.latitude, p.longitude), speedMps: p.speed);

  @override
  Future<bool> serviceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<RiderFix?> lastKnown() async {
    final p = await Geolocator.getLastKnownPosition();
    return p == null ? null : _fix(p);
  }

  @override
  Stream<RiderFix> fixes() => Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 2),
    ),
  ).map(_fix);

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
