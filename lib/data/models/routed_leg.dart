import 'package:latlong2/latlong.dart';

import 'json.dart';

/// One leg of a custom loop between two of its points, snapped to roads by
/// the route-through-points Edge Function.
class RoutedLeg {
  const RoutedLeg({
    required this.points,
    required this.distanceM,
    required this.durationS,
  });

  /// A leg between two points at the same spot.
  RoutedLeg.empty(LatLng at) : points = [at], distanceM = 0, durationS = 0;

  final List<LatLng> points;
  final int distanceM;
  final int durationS;

  /// `{coordinates: [[lng, lat], ...], distance_m, duration_s}`.
  factory RoutedLeg.fromJson(Json json) => RoutedLeg(
    points: [
      for (final c in json['coordinates'] as List)
        LatLng(
          ((c as List)[1] as num).toDouble(),
          (c[0] as num).toDouble(),
        ),
    ],
    distanceM: (json['distance_m'] as num).toInt(),
    durationS: (json['duration_s'] as num).toInt(),
  );
}
