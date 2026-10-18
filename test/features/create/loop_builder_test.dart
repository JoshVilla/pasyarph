import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/data/models/routed_leg.dart';
import 'package:pasyarph/features/create/loop_builder.dart';

const s = LatLng(16.6, 121.4);
const a = LatLng(16.61, 121.4);
const b = LatLng(16.61, 121.41);
const c = LatLng(16.6, 121.42);

RoutedLeg leg(LatLng from, LatLng to, {int m = 1000, int s = 100}) =>
    RoutedLeg(
      points: [from, LatLng(from.latitude + 0.001, from.longitude), to],
      distanceM: m,
      durationS: s,
    );

Map<String, RoutedLeg> legs(List<(LatLng, LatLng)> pairs) => {
  for (final (x, y) in pairs) legKey(x, y): leg(x, y),
};

void main() {
  group('stops', () {
    test('S, the points, then back to S', () {
      expect(loopStops(s, [a, b]), [s, a, b, s]);
      expect(loopStops(s, []), [s]);
    });

    test('leg keys are directional and ignore sub-10 cm noise', () {
      expect(legKey(a, b), isNot(legKey(b, a)));
      expect(
        legKey(const LatLng(16.61000001, 121.4), b),
        legKey(a, b),
      );
    });
  });

  group('missing runs', () {
    test('everything missing is one run through all stops', () {
      expect(missingRuns([s, a, b, s], {}), [
        [s, a, b, s],
      ]);
    });

    test('only unrouted legs, grouped where they touch', () {
      // Moving b breaks a → b and b → c.
      final stops = [s, a, b, c, s];
      final cached = legs([(s, a), (c, s)]);
      expect(missingRuns(stops, cached), [
        [a, b, c],
      ]);

      // Two separate gaps are two runs.
      final gaps = legs([(a, b), (c, s)]);
      expect(missingRuns(stops, gaps), [
        [s, a],
        [b, c],
      ]);
    });

    test('nothing to route when every leg is cached', () {
      expect(missingRuns([s, a, s], legs([(s, a), (a, s)])), isEmpty);
      expect(missingRuns([s], {}), isEmpty);
    });

    test('two points at the same spot need no routing', () {
      expect(missingRuns([s, a, a, s], legs([(s, a), (a, s)])), isEmpty);
    });
  });

  group('shape', () {
    test('routed legs join into one line; the closing leg is dashed', () {
      final shape = loopShape([s, a, b, s], legs([(s, a), (a, b), (b, s)]));
      expect(shape.solid, hasLength(1));
      expect(shape.solid.single.first, s);
      expect(shape.solid.single.last, b);
      // No duplicated point where legs meet.
      expect(shape.solid.single, hasLength(5));
      expect(shape.dashed, [leg(b, s).points]);
    });

    test('legs still routing are straight dashed lines', () {
      final shape = loopShape([s, a, b, s], legs([(s, a)]));
      expect(shape.solid, [leg(s, a).points]);
      expect(shape.dashed, [
        [a, b],
        [b, s],
      ]);
    });
  });

  group('totals and route', () {
    test('sum of routed legs, complete once all are routed', () {
      final partial = loopTotals([s, a, b, s], legs([(s, a), (a, b)]));
      expect(partial.distanceM, 2000);
      expect(partial.complete, isFalse);

      final all = legs([(s, a), (a, b), (b, s)]);
      final done = loopTotals([s, a, b, s], all);
      expect((done.distanceM, done.durationS, done.complete), (3000, 300, true));
      expect(loopTotals([s], {}).complete, isFalse);
    });

    test('full route from S back to S, null while a leg is missing', () {
      final all = legs([(s, a), (a, b), (b, s)]);
      final route = fullRoute([s, a, b, s], all)!;
      expect(route.first, s);
      expect(route.last, s);
      expect(route, hasLength(7));
      expect(fullRoute([s, a, b, s], legs([(s, a)])), isNull);
    });

    test('meters to a point along the loop', () {
      final all = legs([(s, a), (a, b), (b, s)]);
      expect(metersToPoint(s, [a, b], 0, all), 1000);
      expect(metersToPoint(s, [a, b], 1, all), 2000);
      expect(metersToPoint(s, [a, b], 1, legs([(s, a)])), isNull);
    });
  });

  group('main stop', () {
    test('defaults to the point farthest from S', () {
      expect(farthestPointIndex(s, [a, c, b]), 1);
    });

    test('follows its point when another is removed', () {
      expect(mainStopAfterRemoving(2, 0), 1);
      expect(mainStopAfterRemoving(2, 3), 2);
      expect(mainStopAfterRemoving(2, 2), isNull);
      expect(mainStopAfterRemoving(null, 0), isNull);
    });
  });

  test('labels', () {
    expect(pointsLabel(1), '1 point · closes back to start');
    expect(pointsLabel(3), '3 points · closes back to start');
    expect(hintFor(0), 'Tap the map to add a point');
    expect(hintFor(3), 'Tap the map to add a point');
    expect(hintFor(maxLoopPoints), '15 points is the limit');
  });
}
