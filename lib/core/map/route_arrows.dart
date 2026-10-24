import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../theme/pasyar_colors.dart';

/// Screen distance between direction arrows, and before the first one.
const routeArrowSpacing = 80.0;

/// Where to draw direction arrows along a line through [points] (screen
/// pixels): every [spacing] px, starting [spacing] / 2 in, each with the
/// angle of the segment it sits on (radians, 0 = pointing right).
List<({Offset at, double angle})> arrowPlacements(
  List<Offset> points, {
  double spacing = routeArrowSpacing,
}) {
  final out = <({Offset at, double angle})>[];
  var next = spacing / 2;
  var walked = 0.0;
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1];
    final b = points[i];
    final d = b - a;
    final length = d.distance;
    if (length == 0) continue;
    // Not at the very end: that's the start point, under its marker.
    while (next < walked + length) {
      final t = (next - walked) / length;
      out.add((at: a + d * t, angle: math.atan2(d.dy, d.dx)));
      next += spacing;
    }
    walked += length;
  }
  return out;
}

/// Small white chevrons along [route] showing which way the loop goes,
/// evenly spaced on screen at any zoom. Put it right after the route's
/// PolylineLayer in a FlutterMap.
class RouteArrowsLayer extends StatelessWidget {
  const RouteArrowsLayer({super.key, required this.routes});

  /// Each line is drawn in the direction of its points.
  final List<List<LatLng>> routes;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final lines = [
      for (final r in routes)
        if (r.length > 1) [for (final p in r) camera.latLngToScreenOffset(p)],
    ];
    return IgnorePointer(
      child: CustomPaint(
        size: camera.size,
        painter: _ArrowsPainter(lines),
      ),
    );
  }
}

class _ArrowsPainter extends CustomPainter {
  _ArrowsPainter(this.lines);

  final List<List<Offset>> lines;

  @override
  void paint(Canvas canvas, Size size) {
    final visible = (Offset.zero & size).inflate(12);
    final paint = Paint()
      ..color = PasyarColors.card
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // A "›" chevron, 4 px each way, fits inside the 6 px route line.
    final chevron = Path()
      ..moveTo(-2, -3.5)
      ..lineTo(2, 0)
      ..lineTo(-2, 3.5);
    for (final line in lines) {
      for (final arrow in arrowPlacements(line)) {
        if (!visible.contains(arrow.at)) continue;
        canvas
          ..save()
          ..translate(arrow.at.dx, arrow.at.dy)
          ..rotate(arrow.angle)
          ..drawPath(chevron, paint)
          ..restore();
      }
    }
  }

  @override
  bool shouldRepaint(_ArrowsPainter old) => true;
}
