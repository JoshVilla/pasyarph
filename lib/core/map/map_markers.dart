import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/pasyar_colors.dart';
import '../theme/pasyar_text_styles.dart';

const _ringWidth = 3.0;

/// Rider location: 10 px `rider` dot, 3 px white ring, optional 24 px halo at
/// 15% opacity.
class RiderDot extends StatelessWidget {
  const RiderDot({super.key, this.halo = true});

  final bool halo;

  static double sizeFor({required bool halo}) => halo ? 48 : 26;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(sizeFor(halo: halo)),
      painter: _RiderDotPainter(halo: halo),
    );
  }
}

class _RiderDotPainter extends CustomPainter {
  _RiderDotPainter({required this.halo});

  final bool halo;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (halo) {
      canvas.drawCircle(
        c,
        24,
        Paint()..color = PasyarColors.rider.withValues(alpha: 0.15),
      );
    }
    _ringedCircle(canvas, c, 10, PasyarColors.rider);
  }

  @override
  bool shouldRepaint(_RiderDotPainter oldDelegate) => oldDelegate.halo != halo;
}

/// Rider heading arrow used while riding. [heading] is degrees clockwise from
/// north on screen.
class RiderArrow extends StatelessWidget {
  const RiderArrow({super.key, required this.heading});

  final double heading;

  static const size = 44.0;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size.square(size),
      painter: _RiderArrowPainter(heading),
    );
  }
}

class _RiderArrowPainter extends CustomPainter {
  _RiderArrowPainter(this.heading);

  final double heading;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      20,
      Paint()..color = PasyarColors.rider.withValues(alpha: 0.18),
    );
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(heading * math.pi / 180);
    final arrow = Path()
      ..moveTo(0, -12)
      ..lineTo(9, 10)
      ..lineTo(0, 5)
      ..lineTo(-9, 10)
      ..close();
    canvas
      ..drawPath(arrow, Paint()..color = PasyarColors.rider)
      ..drawPath(
        arrow,
        Paint()
          ..color = PasyarColors.card
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_RiderArrowPainter oldDelegate) =>
      oldDelegate.heading != heading;
}

/// Main stop: `ink` circle with a white ring and a white flag.
class MainStopMarker extends StatelessWidget {
  const MainStopMarker({super.key, this.radius = 16});

  /// 16 on previews, 14 while riding.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final side = (radius + _ringWidth) * 2;
    return CustomPaint(
      size: Size.square(side),
      painter: _MainStopPainter(radius),
    );
  }
}

class _MainStopPainter extends CustomPainter {
  _MainStopPainter(this.radius);

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    _ringedCircle(canvas, c, radius, PasyarColors.ink);

    // Flag from the mockup SVG, drawn for a 16 px marker and scaled.
    final s = radius / 16;
    Offset p(double x, double y) => c + Offset(x * s, y * s);
    final flag = Path()
      ..moveTo(p(-5, 8).dx, p(-5, 8).dy)
      ..lineTo(p(-5, -8).dx, p(-5, -8).dy)
      ..lineTo(p(5, -8).dx, p(5, -8).dy)
      ..lineTo(p(2, -4).dx, p(2, -4).dy)
      ..lineTo(p(5, 0).dx, p(5, 0).dy)
      ..lineTo(p(-5, 0).dx, p(-5, 0).dy);
    canvas.drawPath(
      flag,
      Paint()
        ..color = PasyarColors.card
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_MainStopPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// Custom loop point: 13 px `accent` circle with a white number. The start
/// point uses `rider` and the label "S".
class LoopPointMarker extends StatelessWidget {
  const LoopPointMarker({super.key, required this.label}) : isStart = false;

  const LoopPointMarker.start({super.key}) : label = 'S', isStart = true;

  final String label;
  final bool isStart;

  static const size = (13 + _ringWidth) * 2;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _LoopPointPainter(
          isStart ? PasyarColors.rider : PasyarColors.accent,
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: PasyarFonts.body,
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w700,
              color: PasyarColors.card,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoopPointPainter extends CustomPainter {
  _LoopPointPainter(this.fill);

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) =>
      _ringedCircle(canvas, size.center(Offset.zero), 13, fill);

  @override
  bool shouldRepaint(_LoopPointPainter oldDelegate) => oldDelegate.fill != fill;
}

/// Fuel station along a loop: a small white disc with an `ink` pump icon,
/// quieter than the main stop so it doesn't compete with it.
class FuelMarker extends StatelessWidget {
  const FuelMarker({super.key});

  static const size = 24.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PasyarColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: PasyarColors.lineStrong, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F15171C),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: const Icon(LucideIcons.fuel, size: 13, color: PasyarColors.ink),
    );
  }
}

void _ringedCircle(Canvas canvas, Offset c, double r, Color fill) {
  canvas
    ..drawCircle(c, r, Paint()..color = fill)
    ..drawCircle(
      c,
      r,
      Paint()
        ..color = PasyarColors.card
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringWidth,
    );
}

/// Ready-made flutter_map markers.
abstract final class PasyarMarkers {
  static Marker rider(LatLng point, {bool halo = true}) {
    final size = RiderDot.sizeFor(halo: halo);
    return Marker(
      point: point,
      width: size,
      height: size,
      child: RiderDot(halo: halo),
    );
  }

  static Marker riderArrow(LatLng point, {required double heading}) => Marker(
    point: point,
    width: RiderArrow.size,
    height: RiderArrow.size,
    child: RiderArrow(heading: heading),
  );

  static Marker mainStop(LatLng point, {double radius = 16}) {
    final size = (radius + _ringWidth) * 2;
    return Marker(
      point: point,
      width: size,
      height: size,
      child: MainStopMarker(radius: radius),
    );
  }

  static Marker fuel(LatLng point) => Marker(
    point: point,
    width: FuelMarker.size,
    height: FuelMarker.size,
    child: const FuelMarker(),
  );

  static Marker loopPoint(LatLng point, int number) => Marker(
    point: point,
    width: LoopPointMarker.size,
    height: LoopPointMarker.size,
    child: LoopPointMarker(label: '$number'),
  );

  static Marker loopStart(LatLng point) => Marker(
    point: point,
    width: LoopPointMarker.size,
    height: LoopPointMarker.size,
    child: const LoopPointMarker.start(),
  );
}
