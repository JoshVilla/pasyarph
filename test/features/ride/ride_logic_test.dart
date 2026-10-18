import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/features/ride/ride_logic.dart';

const _d = Distance();

/// 12 km rectangle loop (2 km N, 4 km E, 2 km S, 4 km W), a point every
/// 100 m.
List<LatLng> _rectangle() {
  const start = LatLng(16.672, 121.457);
  final out = [start];
  var at = start;
  for (final (bearing, meters) in [
    (0, 2000),
    (90, 4000),
    (180, 2000),
    (270, 4000),
  ]) {
    for (var m = 100; m <= meters; m += 100) {
      at = _d.offset(at, 100, bearing);
      out.add(at);
    }
  }
  return out;
}

void main() {
  final loop = _rectangle();
  final tracker = RouteTracker(loop);

  group('RouteTracker', () {
    test('length, distance along, and distance off the road', () {
      expect(tracker.lengthM, closeTo(12000, 50));
      final beside = _d.offset(loop[30], 80, 0); // 3 km in, 80 m north
      final at = tracker.locate(beside);
      expect(at.alongM, closeTo(3000, 20));
      expect(at.offRouteM, closeTo(80, 5));
    });

    test('at home: "near" tells leaving from arriving', () {
      final home = loop.first;
      expect(tracker.locate(home, near: 0).alongM, lessThan(100));
      expect(
        tracker.locate(home, near: 11800).alongM,
        greaterThan(tracker.lengthM - 100),
      );
    });

    test('far from the window: falls back to the whole route', () {
      final farCorner = loop[60]; // 6 km in
      expect(tracker.locate(farCorner, near: 0).alongM, closeTo(6000, 20));
    });

    test('split: ridden part and the rest meet at the rider', () {
      final split = tracker.splitAt(loop, 4550);
      expect(split.behind.first, loop.first);
      expect(split.ahead.last, loop.last);
      expect(split.behind.last, split.ahead.first);
      expect(tracker.locate(split.ahead.first).alongM, closeTo(4550, 5));
    });
  });

  group('DwellDetector', () {
    final stop = loop[60];
    final t0 = DateTime(2026, 10, 18, 9);

    test('stopped near the place for 20 s counts', () {
      final d = DwellDetector(target: stop);
      expect(d.update(stop, 0, t0), isFalse);
      expect(d.update(stop, 2, t0.add(const Duration(seconds: 10))), isFalse);
      expect(d.update(stop, 0, t0.add(const Duration(seconds: 20))), isTrue);
    });

    test('riding past does not', () {
      final d = DwellDetector(target: stop);
      for (var s = 0; s <= 60; s += 5) {
        expect(d.update(stop, 30, t0.add(Duration(seconds: s))), isFalse);
      }
    });

    test('leaving the radius resets the timer', () {
      final d = DwellDetector(target: stop);
      d.update(stop, 0, t0);
      d.update(_d.offset(stop, 400, 0), 0, t0.add(const Duration(seconds: 15)));
      expect(d.update(stop, 0, t0.add(const Duration(seconds: 25))), isFalse);
      expect(d.update(stop, 0, t0.add(const Duration(seconds: 45))), isTrue);
    });
  });

  group('Google Maps link', () {
    String fmt(LatLng p) =>
        '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';

    test('9 stops in order, the main stop among them, back home', () {
      final mainStop = loop[61];
      final url = googleMapsLink(
        route: loop,
        mainStop: mainStop,
        avoidHighways: true,
      );
      expect(url.host, 'www.google.com');
      expect(url.path, '/maps/dir/');
      final q = url.queryParameters;
      expect(q['api'], '1');
      expect(q['travelmode'], 'driving');
      expect(q['dir_action'], 'navigate');
      expect(q['avoid'], 'highways');
      expect(q.containsKey('origin'), isFalse); // starts from the rider
      expect(q['destination'], fmt(loop.last));

      final stops = q['waypoints']!.split('|');
      expect(stops, hasLength(9));
      expect(stops, contains(fmt(mainStop)));

      final alongs = [
        for (final s in stops)
          tracker
              .locate(
                LatLng(
                  double.parse(s.split(',')[0]),
                  double.parse(s.split(',')[1]),
                ),
              )
              .alongM,
      ];
      expect(alongs, orderedEquals([...alongs]..sort()));
    });

    test('no highway avoidance unless asked', () {
      expect(
        googleMapsLink(route: loop).queryParameters.containsKey('avoid'),
        isFalse,
      );
    });
  });
}
