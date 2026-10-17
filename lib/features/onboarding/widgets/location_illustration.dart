import 'package:flutter/material.dart';

import '../../../core/theme/pasyar_theme.dart';

/// 180 px round map with the loop, from mockup 11 (SVG viewBox
/// "40 90 310 310" scaled into the circle).
class LocationIllustration extends StatelessWidget {
  const LocationIllustration({super.key});

  static const size = 180.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _LoopPainter()),
        ),
      ),
    );
  }
}

class _LoopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = PasyarColors.mapGround,
    );

    final s = size.width / 310;
    canvas
      ..save()
      ..scale(s)
      ..translate(-40, -90);

    Path poly(List<Offset> pts, {bool close = false}) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      if (close) p.close();
      return p;
    }

    final road = Paint()
      ..color = PasyarColors.card
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPath(
        poly(const [
          Offset(0, 300),
          Offset(120, 290),
          Offset(195, 300),
          Offset(300, 270),
          Offset(390, 260),
        ]),
        road,
      )
      ..drawPath(
        poly(const [
          Offset(195, 0),
          Offset(190, 140),
          Offset(195, 300),
          Offset(210, 420),
        ]),
        road,
      )
      ..drawPath(
        poly(const [
          Offset(195, 300),
          Offset(120, 290),
          Offset(60, 160),
          Offset(190, 140),
          Offset(320, 140),
          Offset(300, 270),
        ], close: true),
        Paint()
          ..color = PasyarColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(
        const Offset(195, 300),
        34,
        Paint()..color = PasyarColors.rider.withValues(alpha: 0.18),
      )
      ..drawCircle(
        const Offset(195, 300),
        14,
        Paint()..color = PasyarColors.rider,
      )
      ..drawCircle(
        const Offset(195, 300),
        14,
        Paint()
          ..color = PasyarColors.card
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_LoopPainter oldDelegate) => false;
}
