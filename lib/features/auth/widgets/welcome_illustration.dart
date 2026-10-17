import 'package:flutter/material.dart';

import '../../../core/theme/pasyar_theme.dart';

/// The dark map with the orange loop from design/mockups/07-welcome.html,
/// drawn in its 390 × 470 viewBox and scaled to the available width
/// (anchored at the top, clipped at the bottom).
class WelcomeIllustration extends StatelessWidget {
  const WelcomeIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(painter: _WelcomePainter(), size: Size.infinite),
    );
  }
}

class _WelcomePainter extends CustomPainter {
  static const _viewWidth = 390.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _viewWidth;
    canvas
      ..save()
      ..scale(s);

    Path poly(List<Offset> pts, {bool close = false}) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      if (close) p.close();
      return p;
    }

    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final minor = stroke(PasyarColors.inkRoad, 3);
    for (final pts in const [
      [
        Offset(40, 0),
        Offset(60, 160),
        Offset(120, 290),
        Offset(90, 420),
        Offset(70, 470),
      ],
      [Offset(300, 270), Offset(320, 140), Offset(330, 0)],
      [Offset(300, 270), Offset(340, 420), Offset(350, 470)],
      [Offset(60, 160), Offset(190, 140), Offset(320, 140)],
      [Offset(90, 420), Offset(210, 420), Offset(340, 420)],
    ]) {
      canvas.drawPath(poly(pts), minor);
    }

    final major = stroke(PasyarColors.inkRoadMajor, 7);
    for (final pts in const [
      [
        Offset(0, 300),
        Offset(120, 290),
        Offset(195, 300),
        Offset(300, 270),
        Offset(390, 260),
      ],
      [
        Offset(195, 0),
        Offset(190, 140),
        Offset(195, 300),
        Offset(210, 420),
        Offset(200, 470),
      ],
    ]) {
      canvas.drawPath(poly(pts), major);
    }

    canvas.drawPath(
      poly(const [
        Offset(195, 300),
        Offset(120, 290),
        Offset(60, 160),
        Offset(190, 140),
        Offset(320, 140),
        Offset(300, 270),
      ], close: true),
      stroke(PasyarColors.accent, 7)..strokeCap = StrokeCap.butt,
    );

    // Main stop: white circle with an ink flag.
    canvas.drawCircle(
      const Offset(320, 140),
      17,
      Paint()..color = PasyarColors.card,
    );
    canvas.drawPath(
      poly(const [
        Offset(315, 149),
        Offset(315, 132),
        Offset(325, 132),
        Offset(322, 136),
        Offset(325, 140),
        Offset(315, 140),
      ]),
      stroke(PasyarColors.ink, 2.2)..strokeCap = StrokeCap.butt,
    );

    // Rider: halo, then dot with white ring.
    canvas
      ..drawCircle(
        const Offset(195, 300),
        26,
        Paint()..color = PasyarColors.rider.withValues(alpha: 0.25),
      )
      ..drawCircle(
        const Offset(195, 300),
        11,
        Paint()..color = PasyarColors.rider,
      )
      ..drawCircle(const Offset(195, 300), 11, stroke(PasyarColors.card, 3))
      ..restore();
  }

  @override
  bool shouldRepaint(_WelcomePainter oldDelegate) => false;
}
