import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Where the rider is on a loop: how far along, and how far off the road.
class RoutePosition {
  const RoutePosition({required this.alongM, required this.offRouteM});

  final double alongM;
  final double offRouteM;
}

/// Places points on a route. A loop starts and ends at the same spot, so
/// [locate] takes the last known position ([near]) and searches around it
/// first; otherwise "just left home" and "almost home" look the same.
class RouteTracker {
  RouteTracker(List<LatLng> route)
    : assert(route.length >= 2),
      _origin = route.first,
      _kx = _metersPerDegLng(route.first.latitude) {
    for (final p in route) {
      _pts.add(_project(p));
    }
    _along.add(0);
    for (var i = 1; i < _pts.length; i++) {
      _along.add(_along[i - 1] + _dist(_pts[i - 1], _pts[i]));
    }
  }

  static const _metersPerDegLat = 111320.0;
  static double _metersPerDegLng(double lat) =>
      _metersPerDegLat * math.cos(lat * math.pi / 180);

  /// Search this far behind and ahead of [near] first.
  static const _behindM = 1000.0;
  static const _aheadM = 20000.0;

  /// Farther than this from the windowed match, search the whole route.
  static const _fallbackM = 200.0;

  final LatLng _origin;
  final double _kx;
  final _pts = <math.Point<double>>[];
  final _along = <double>[];

  double get lengthM => _along.last;

  math.Point<double> _project(LatLng p) => math.Point(
    (p.longitude - _origin.longitude) * _kx,
    (p.latitude - _origin.latitude) * _metersPerDegLat,
  );

  static double _dist(math.Point<double> a, math.Point<double> b) =>
      (a - b).magnitude;

  RoutePosition locate(LatLng point, {double? near}) {
    final p = _project(point);
    if (near != null) {
      final windowed = _best(p, near - _behindM, near + _aheadM);
      if (windowed.offRouteM <= _fallbackM) return windowed;
    }
    return _best(p, double.negativeInfinity, double.infinity);
  }

  /// The route cut at [alongM]: the part behind the rider and the part
  /// ahead, sharing the cut point.
  ({List<LatLng> behind, List<LatLng> ahead}) splitAt(
    List<LatLng> route,
    double alongM,
  ) {
    var i = 1;
    while (i < _along.length - 1 && _along[i] < alongM) {
      i++;
    }
    final span = _along[i] - _along[i - 1];
    final t = span == 0
        ? 0.0
        : ((alongM - _along[i - 1]) / span).clamp(0.0, 1.0);
    final a = route[i - 1];
    final b = route[i];
    final cut = LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
    return (
      behind: [...route.sublist(0, i), cut],
      ahead: [cut, ...route.sublist(i)],
    );
  }

  RoutePosition _best(math.Point<double> p, double from, double to) {
    var best = const RoutePosition(alongM: 0, offRouteM: double.infinity);
    for (var i = 1; i < _pts.length; i++) {
      if (_along[i] < from || _along[i - 1] > to) continue;
      final a = _pts[i - 1];
      final b = _pts[i];
      final ab = b - a;
      final len2 = ab.x * ab.x + ab.y * ab.y;
      final t = len2 == 0
          ? 0.0
          : (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / len2).clamp(0.0, 1.0);
      final q = math.Point(a.x + ab.x * t, a.y + ab.y * t);
      final d = _dist(p, q);
      if (d < best.offRouteM) {
        best = RoutePosition(
          alongM: _along[i - 1] + t * (_along[i] - _along[i - 1]),
          offRouteM: d,
        );
      }
    }
    return best;
  }
}

/// True once the rider has stayed within [radiusM] of [target], slower than
/// [maxSpeedKmh], for [dwell]: they stopped there, not just rode past.
class DwellDetector {
  DwellDetector({
    required this.target,
    this.radiusM = 150,
    this.maxSpeedKmh = 5,
    this.dwell = const Duration(seconds: 20),
  });

  final LatLng target;
  final double radiusM;
  final double maxSpeedKmh;
  final Duration dwell;

  static const _distance = Distance();
  DateTime? _since;

  bool update(LatLng position, double speedKmh, DateTime now) {
    final close = _distance(position, target) <= radiusM;
    if (!close || speedKmh >= maxSpeedKmh) {
      _since = null;
      return false;
    }
    _since ??= now;
    return now.difference(_since!) >= dwell;
  }
}

/// Google Maps allows up to 9 stops in a link opened in its app.
const googleMapsMaxWaypoints = 9;

/// A Google Maps link that navigates the loop from where the rider is:
/// up to [maxWaypoints] stops spread evenly along it, one of them the
/// [mainStop], then back to the start. Google routes between the stops
/// itself, so the closer together they are the closer it follows the loop.
Uri googleMapsLink({
  required List<LatLng> route,
  LatLng? mainStop,
  bool avoidHighways = false,
  int maxWaypoints = googleMapsMaxWaypoints,
}) {
  final tracker = RouteTracker(route);
  final stops = <({double along, LatLng point})>[];

  // Route points nearest to evenly spaced distances (points are on roads).
  final along = <double>[0];
  const distance = Distance();
  for (var i = 1; i < route.length; i++) {
    along.add(along[i - 1] + distance(route[i - 1], route[i]));
  }
  var j = 0;
  for (var k = 1; k <= maxWaypoints; k++) {
    final target = along.last * k / (maxWaypoints + 1);
    while (j < along.length - 1 && along[j] < target) {
      j++;
    }
    stops.add((along: along[j], point: route[j]));
  }

  // The main stop replaces the waypoint nearest to it along the loop.
  if (mainStop != null && stops.isNotEmpty) {
    final stopAlong =
        tracker.locate(mainStop).alongM / tracker.lengthM * along.last;
    var nearest = 0;
    for (var k = 1; k < stops.length; k++) {
      if ((stops[k].along - stopAlong).abs() <
          (stops[nearest].along - stopAlong).abs()) {
        nearest = k;
      }
    }
    stops[nearest] = (along: stopAlong, point: mainStop);
  }

  String fmt(LatLng p) =>
      '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';

  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': fmt(route.last),
    'waypoints': stops.map((s) => fmt(s.point)).join('|'),
    'travelmode': 'driving',
    'dir_action': 'navigate',
    if (avoidHighways) 'avoid': 'highways',
  });
}
