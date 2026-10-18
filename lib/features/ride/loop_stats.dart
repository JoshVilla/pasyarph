import 'package:latlong2/latlong.dart';

import '../../data/models/generated_loop.dart';
import '../../data/models/loop.dart';

/// Loops riding more than this share of the same road twice are rerolled.
const maxBacktracking = 0.25;

/// Extra seeds tried when a loop backtracks too much.
const extraSeeds = 3;

enum CurvyLevel {
  low('Low'),
  medium('Medium'),
  high('High');

  const CurvyLevel(this.label);
  final String label;
}

/// Curviness score (heading change in degrees per km) to a level. Tuned on
/// loops around Cordon, Isabela: flat farm roads score ~130, the hills
/// 300+.
const curvyMediumFrom = 150.0;
const curvyHighFrom = 300.0;

CurvyLevel curvyLevel(double score) {
  if (score >= curvyHighFrom) return CurvyLevel.high;
  if (score >= curvyMediumFrom) return CurvyLevel.medium;
  return CurvyLevel.low;
}

/// "118 km"; under 10 km one decimal, e.g. "8.4 km".
String formatDistance(int meters) {
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}

/// "3 h 50", "4 h", or "45 min" (rounded to the minute).
String formatRideTime(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

/// The loop's main stop as the preview shows it.
class StopInfo {
  const StopInfo({
    required this.location,
    required this.metersIn,
    this.name,
    this.type = turnaround,
  });

  static const turnaround = 'turnaround';

  final LatLng location;

  /// Distance along the route from the start.
  final double metersIn;
  final String? name;

  /// viewpoint, waterfall, attraction, food, or [turnaround].
  final String type;

  /// "52 KM IN".
  String get kmInLabel => '${(metersIn / 1000).round()} KM IN';

  static const _typeLabels = {
    'viewpoint': 'Viewpoint',
    'waterfall': 'Waterfall',
    'attraction': 'Attraction',
    'food': 'Food stop',
  };

  /// "Viewpoint", "Food stop", ...; null for the turnaround.
  String? get typeLabel => _typeLabels[type];

  /// Card title: the place's name, else its type, else "Main stop".
  String get title => name ?? typeLabel ?? 'Main stop';
}

/// The function's main stop, or (older responses) the farthest point.
StopInfo stopFor(GeneratedLoop loop) {
  final stop = loop.mainStop;
  if (stop == null) return farthestPoint(loop.route);
  return StopInfo(
    location: stop.location,
    metersIn: (stop.kmIntoRoute ?? 0) * 1000,
    name: stop.name,
    type: stop.type ?? StopInfo.turnaround,
  );
}

/// A fuel station this close (straight line) to the stop is "nearby".
const fuelNearbyM = 3000.0;

/// Card detail line: "Waterfall · gas station nearby".
String stopDetail(StopInfo stop, List<FuelStop> fuel) {
  final nearbyFuel = fuel.any(
    (f) => _distance(f.location, stop.location) <= fuelNearbyM,
  );
  final parts = [
    // A titled place repeats its type here; an untitled one already shows it.
    if (stop.typeLabel != null && stop.name != null) stop.typeLabel!,
    if (stop.type == StopInfo.turnaround) 'Farthest point of the loop',
    if (nearbyFuel) 'gas station nearby',
  ];
  if (parts.isEmpty) return '';
  final text = parts.join(' · ');
  return text[0].toUpperCase() + text.substring(1);
}

const _distance = Distance();

/// The point of the loop farthest (straight line) from the start.
StopInfo farthestPoint(List<LatLng> route) {
  final start = route.first;
  var best = 0;
  var bestDistance = -1.0;
  var along = 0.0;
  var bestAlong = 0.0;
  for (var i = 0; i < route.length; i++) {
    if (i > 0) along += _distance(route[i - 1], route[i]);
    final d = _distance(start, route[i]);
    if (d > bestDistance) {
      bestDistance = d;
      best = i;
      bestAlong = along;
    }
  }
  return StopInfo(location: route[best], metersIn: bestAlong);
}

/// Lowest backtracking first; ties (within 1%) go to the curvier loop.
GeneratedLoop pickBest(List<GeneratedLoop> loops) {
  return loops.reduce((a, b) {
    final diff = a.backtrackingRatio - b.backtrackingRatio;
    if (diff.abs() > 0.01) return diff < 0 ? a : b;
    return a.curvinessScore >= b.curvinessScore ? a : b;
  });
}
