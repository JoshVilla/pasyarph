import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/core/map/route_arrows.dart';

void main() {
  test('every 80 px from 40 px in, pointing along the line', () {
    final arrows = arrowPlacements(const [Offset(0, 0), Offset(200, 0)]);
    expect([for (final a in arrows) a.at.dx], [40, 120]);
    expect(arrows.every((a) => a.angle == 0), isTrue);
  });

  test('spacing carries across corners; angle follows each segment', () {
    final arrows = arrowPlacements(const [
      Offset(0, 0),
      Offset(60, 0),
      Offset(60, 100),
    ]);
    // 40 px along the first segment, then 120 px along = 60 px down.
    expect(arrows.map((a) => a.at), const [Offset(40, 0), Offset(60, 60)]);
    expect(arrows[1].angle, closeTo(math.pi / 2, 1e-9));
  });

  test('the direction of the points is the direction of the arrows', () {
    final back = arrowPlacements(const [Offset(200, 0), Offset(0, 0)]);
    expect(back.first.angle, closeTo(math.pi, 1e-9));
  });

  test('nothing for lines too short or without length', () {
    expect(arrowPlacements(const [Offset(0, 0), Offset(30, 0)]), isEmpty);
    expect(arrowPlacements(const [Offset(5, 5), Offset(5, 5)]), isEmpty);
    expect(arrowPlacements(const [Offset(5, 5)]), isEmpty);
  });
}
