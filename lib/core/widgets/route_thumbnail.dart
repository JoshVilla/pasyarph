import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../theme/pasyar_theme.dart';

/// A loop's shape scaled into a small `mapGround` box: 3 px `accent` line
/// and a start dot. Post screen and feed loop cards.
class RouteThumbnail extends StatelessWidget {
  const RouteThumbnail({
    super.key,
    required this.route,
    this.width = 72,
    this.height = 56,
    this.radius = PasyarRadius.photoSlot,
    this.startColor = PasyarColors.rider,
  });

  final List<LatLng> route;
  final double width;
  final double height;
  final double radius;
  final Color startColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(painter: _RouteThumbPainter(route, startColor)),
      ),
    );
  }
}

class _RouteThumbPainter extends CustomPainter {
  const _RouteThumbPainter(this.route, this.startColor);

  final List<LatLng> route;
  final Color startColor;

  static const _inset = 9.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = PasyarColors.mapGround,
    );
    if (route.length < 2) return;

    // Flat projection: longitude shrinks with latitude.
    final k = math.cos(route.first.latitude * math.pi / 180);
    final xs = [for (final p in route) p.longitude * k];
    final ys = [for (final p in route) -p.latitude];
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final w = size.width - _inset * 2, h = size.height - _inset * 2;
    final scale = math.min(
      w / math.max(maxX - minX, 1e-9),
      h / math.max(maxY - minY, 1e-9),
    );
    final dx = _inset + (w - (maxX - minX) * scale) / 2;
    final dy = _inset + (h - (maxY - minY) * scale) / 2;
    Offset at(int i) =>
        Offset(dx + (xs[i] - minX) * scale, dy + (ys[i] - minY) * scale);

    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < route.length; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = PasyarColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(at(0), 3.5, Paint()..color = startColor);
  }

  @override
  bool shouldRepaint(_RouteThumbPainter oldDelegate) =>
      !identical(oldDelegate.route, route) ||
      oldDelegate.startColor != startColor;
}
