import 'package:latlong2/latlong.dart';

import '../geo/geo_codec.dart';
import 'json.dart';
import 'loop.dart';

/// How long the rider wants to ride. [value] is what generate-loop expects.
enum LoopDuration {
  quick('quick', 'QUICK', 'about 1 hr'),
  halfDay('half', 'HALF-DAY', 'about 4 hr'),
  fullDay('full', 'FULL DAY', '6 hr +');

  const LoopDuration(this.value, this.title, this.subtitle);

  final String value;
  final String title;
  final String subtitle;
}

/// One turn instruction from GraphHopper.
class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.name,
    required this.distanceM,
    required this.durationS,
    required this.sign,
    required this.fromIndex,
    required this.toIndex,
  });

  final String instruction;

  /// Road name; empty when the road has none.
  final String name;
  final int distanceM;
  final int durationS;

  /// GraphHopper sign: -2 left, 2 right, 0 continue, 4 finish,
  /// 6 roundabout, ... Unknown values may appear.
  final int sign;

  /// Range of route points this step covers.
  final int fromIndex;
  final int toIndex;

  factory RouteStep.fromJson(Json json) {
    final wayPoints = json['way_points'] as List;
    return RouteStep(
      instruction: json['instruction'] as String,
      name: json['name'] as String,
      distanceM: (json['distance_m'] as num).toInt(),
      durationS: (json['duration_s'] as num).toInt(),
      sign: (json['sign'] as num).toInt(),
      fromIndex: (wayPoints[0] as num).toInt(),
      toIndex: (wayPoints[1] as num).toInt(),
    );
  }
}

/// Response of the generate-loop Edge Function. Not saved yet; the full
/// [route] starts at the rider's location, so it stays on the device until
/// it is saved (and trimmed) as a loop.
class GeneratedLoop {
  const GeneratedLoop({
    required this.route,
    required this.distanceM,
    required this.durationS,
    required this.steps,
    required this.seed,
    required this.backtrackingRatio,
    required this.curvinessScore,
    this.motorwayM = 0,
    this.unpavedM = 0,
    this.mainStop,
    this.fuelStops = const [],
    this.warnings = const [],
  });

  final List<LatLng> route;
  final int distanceM;
  final int durationS;
  final List<RouteStep> steps;

  /// Seed that produced this loop; Shuffle sends a different one.
  final int seed;

  /// Share of the route (0–1) that rides the same road twice.
  final double backtrackingRatio;

  /// Heading change in degrees per km; higher is twistier.
  final double curvinessScore;

  /// Meters on expressways.
  final int motorwayM;

  /// Meters on roads tagged unpaved. Most roads have no surface tag, so
  /// this is a lower bound.
  final int unpavedM;

  /// Picked by the function from nearby places; null from older servers.
  final MainStop? mainStop;

  /// Fuel stations along the loop, in riding order.
  final List<FuelStop> fuelStops;

  /// Things the rider should know, e.g. a request that couldn't be honored.
  final List<String> warnings;

  factory GeneratedLoop.fromJson(Json json) => GeneratedLoop(
    route: GeoCodec.parseLineString(json['route'] as Json),
    distanceM: (json['distance_m'] as num).toInt(),
    durationS: (json['duration_s'] as num).toInt(),
    steps: [
      for (final s in json['steps'] as List) RouteStep.fromJson(s as Json),
    ],
    seed: (json['seed'] as num).toInt(),
    backtrackingRatio: (json['backtracking_ratio'] as num).toDouble(),
    curvinessScore: (json['curviness_score'] as num).toDouble(),
    motorwayM: (json['motorway_m'] as num?)?.toInt() ?? 0,
    unpavedM: (json['unpaved_m'] as num?)?.toInt() ?? 0,
    mainStop: json['main_stop'] == null
        ? null
        : MainStop.fromJson(json['main_stop'] as Json),
    fuelStops: [
      for (final f in json['fuel_stops'] as List? ?? [])
        FuelStop.fromJson(f as Json),
    ],
    warnings: [for (final w in json['warnings'] as List? ?? []) w as String],
  );
}
