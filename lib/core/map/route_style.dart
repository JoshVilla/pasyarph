import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/pasyar_colors.dart';

/// Polylines for a loop, drawn as in design/DESIGN.md ("Route line"):
/// - [ridden]: the part already ridden, 6 px `riddenRoute`, no casing.
/// - [route]: 6 px `accent` with round joins on an 11 px white casing.
/// - [closing]: unconfirmed segment back to start, 4 px dashed `accent`
///   (8 on, 7 off).
///
/// Use with `PolylineLayer(polylines: routePolylines(...))`.
List<Polyline> routePolylines({
  List<LatLng> route = const [],
  List<LatLng> ridden = const [],
  List<LatLng> closing = const [],
}) {
  return [
    if (ridden.length > 1)
      Polyline(
        points: ridden,
        color: PasyarColors.riddenRoute,
        strokeWidth: 6,
        strokeCap: StrokeCap.round,
        strokeJoin: StrokeJoin.round,
      ),
    if (route.length > 1)
      Polyline(
        points: route,
        color: PasyarColors.accent,
        strokeWidth: 6,
        // flutter_map paints the casing at strokeWidth + borderStrokeWidth.
        borderStrokeWidth: 5,
        borderColor: PasyarColors.card,
        strokeJoin: StrokeJoin.round,
      ),
    if (closing.length > 1)
      Polyline(
        points: closing,
        color: PasyarColors.accent,
        strokeWidth: 4,
        strokeCap: StrokeCap.round,
        pattern: StrokePattern.dashed(segments: const [8, 7]),
      ),
  ];
}
