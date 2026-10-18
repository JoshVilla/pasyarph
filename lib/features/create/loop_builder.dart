import 'package:latlong2/latlong.dart';

import '../../data/models/routed_leg.dart';

/// Most points a custom loop can have (S not counted).
const maxLoopPoints = 15;

/// Wait this long after the last change before routing.
const routeDebounce = Duration(milliseconds: 600);

/// S, the rider's points in order, then back to S.
List<LatLng> loopStops(LatLng start, List<LatLng> points) =>
    points.isEmpty ? [start] : [start, ...points, start];

String _key(LatLng p) =>
    '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';

/// Cache key for the leg from [a] to [b] (about 10 cm precision).
String legKey(LatLng a, LatLng b) => '${_key(a)}>${_key(b)}';

/// The routed leg from [a] to [b], or null while it isn't routed. Two
/// points at the same spot need no routing.
RoutedLeg? legBetween(LatLng a, LatLng b, Map<String, RoutedLeg> legs) {
  if (_key(a) == _key(b)) return RoutedLeg.empty(a);
  return legs[legKey(a, b)];
}

/// Stops whose legs aren't routed yet, grouped in runs of consecutive
/// stops: [A, B, C] when A → B and B → C are both missing. One request
/// routes every run.
List<List<LatLng>> missingRuns(
  List<LatLng> stops,
  Map<String, RoutedLeg> legs,
) {
  final runs = <List<LatLng>>[];
  List<LatLng>? run;
  for (var i = 0; i < stops.length - 1; i++) {
    final a = stops[i];
    final b = stops[i + 1];
    if (legBetween(a, b, legs) != null) {
      run = null;
      continue;
    }
    if (run == null) {
      run = [a, b];
      runs.add(run);
    } else {
      run.add(b);
    }
  }
  return runs;
}

/// What the map draws: routed legs as solid route lines (consecutive legs
/// joined), and dashed lines for the closing leg back to S and for legs
/// still waiting for a route (straight between their points).
class LoopShape {
  const LoopShape({required this.solid, required this.dashed});

  final List<List<LatLng>> solid;
  final List<List<LatLng>> dashed;
}

LoopShape loopShape(List<LatLng> stops, Map<String, RoutedLeg> legs) {
  final solid = <List<LatLng>>[];
  final dashed = <List<LatLng>>[];
  List<LatLng>? line;
  for (var i = 0; i < stops.length - 1; i++) {
    final a = stops[i];
    final b = stops[i + 1];
    final leg = legBetween(a, b, legs);
    final closing = i == stops.length - 2;
    if (leg == null || closing) {
      line = null;
      dashed.add(leg?.points ?? [a, b]);
      continue;
    }
    if (line == null) {
      line = [...leg.points];
      solid.add(line);
    } else {
      line.addAll(leg.points.skip(1));
    }
  }
  return LoopShape(solid: solid, dashed: dashed);
}

/// Distance and ride time of the routed legs; [complete] once every leg is
/// routed.
class LoopTotals {
  const LoopTotals({
    required this.distanceM,
    required this.durationS,
    required this.complete,
  });

  final int distanceM;
  final int durationS;
  final bool complete;
}

LoopTotals loopTotals(List<LatLng> stops, Map<String, RoutedLeg> legs) {
  var distance = 0;
  var duration = 0;
  var complete = stops.length > 1;
  for (var i = 0; i < stops.length - 1; i++) {
    final leg = legBetween(stops[i], stops[i + 1], legs);
    if (leg == null) {
      complete = false;
      continue;
    }
    distance += leg.distanceM;
    duration += leg.durationS;
  }
  return LoopTotals(
    distanceM: distance,
    durationS: duration,
    complete: complete,
  );
}

/// The whole loop, S back to S, or null while a leg isn't routed.
List<LatLng>? fullRoute(List<LatLng> stops, Map<String, RoutedLeg> legs) {
  if (stops.length < 2) return null;
  final route = <LatLng>[];
  for (var i = 0; i < stops.length - 1; i++) {
    final leg = legBetween(stops[i], stops[i + 1], legs);
    if (leg == null) return null;
    route.addAll(route.isEmpty ? leg.points : leg.points.skip(1));
  }
  // A line needs two points even when everything is at one spot.
  return route.length < 2 ? null : route;
}

/// Meters along the loop from S to point [index] (0 = the first point
/// after S), or null while a leg on the way isn't routed.
int? metersToPoint(
  LatLng start,
  List<LatLng> points,
  int index,
  Map<String, RoutedLeg> legs,
) {
  final stops = loopStops(start, points);
  var meters = 0;
  for (var i = 0; i <= index; i++) {
    final leg = legBetween(stops[i], stops[i + 1], legs);
    if (leg == null) return null;
    meters += leg.distanceM;
  }
  return meters;
}

const _distance = Distance();

/// Default main stop: the point farthest (straight line) from S.
int farthestPointIndex(LatLng start, List<LatLng> points) {
  var best = 0;
  var bestM = -1.0;
  for (var i = 0; i < points.length; i++) {
    final m = _distance.as(LengthUnit.Meter, start, points[i]);
    if (m > bestM) {
      best = i;
      bestM = m;
    }
  }
  return best;
}

/// The main stop's index after point [removed] is taken out: null when it
/// was the main stop itself (back to the default).
int? mainStopAfterRemoving(int? mainStop, int removed) {
  if (mainStop == null || mainStop == removed) return null;
  return mainStop > removed ? mainStop - 1 : mainStop;
}

/// "3 points · closes back to start".
String pointsLabel(int count) =>
    '$count ${count == 1 ? 'point' : 'points'} · closes back to start';

/// The floating hint over the map. Teaches one gesture at a time while the
/// loop grows.
String hintFor(int count) => switch (count) {
  >= maxLoopPoints => '$maxLoopPoints points is the limit',
  1 => 'Tap a point for the main stop',
  2 => 'Hold a point to remove it',
  _ => 'Tap the map to add a point',
};
