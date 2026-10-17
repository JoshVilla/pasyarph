import 'package:latlong2/latlong.dart';

/// The loop from the mockups (design/mockups/02-loop-preview.html), placed
/// near Cordon, Isabela. Used only by the dev widget gallery and tests.
abstract final class DemoRoutes {
  static const center = LatLng(16.67, 121.45);

  // Mockup SVG coordinates, 1 px ≈ 0.0002°.
  static LatLng _p(double x, double y) => LatLng(
    center.latitude - (y - 300) * 0.0002,
    center.longitude + (x - 195) * 0.0002,
  );

  static final start = _p(195, 300);
  static final mainStop = _p(320, 140);
  static final rider = _p(110, 152);
  static final point1 = _p(60, 160);
  static final point2 = _p(190, 140);

  static final loop = [
    start,
    _p(120, 290),
    point1,
    point2,
    mainStop,
    _p(300, 270),
    start,
  ];

  /// Riding: ridden part, then what's left.
  static final ridden = [start, _p(120, 290), point1, rider];
  static final remaining = [rider, point2, mainStop, _p(300, 270), start];

  /// Create: snapped route so far, then the dashed closing segment.
  static final created = [start, _p(120, 290), point1, point2, mainStop];
  static final closing = [mainStop, _p(300, 270), start];
}
