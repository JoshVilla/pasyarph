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

  group('OffLoopDetector', () {
    final t0 = DateTime(2026, 10, 18, 9);
    DateTime at(int s) => t0.add(Duration(seconds: s));

    test('off the loop for 20 s: one alert', () {
      final d = OffLoopDetector();
      expect(d.update(400, at(0)), isFalse);
      expect(d.update(400, at(10)), isFalse);
      expect(d.update(400, at(20)), isTrue);
      expect(d.isOff, isTrue);
      expect(d.update(600, at(40)), isFalse); // still off, no repeat
    });

    test('a short stray (a GPS jump) is not leaving', () {
      final d = OffLoopDetector();
      d.update(400, at(0));
      d.update(20, at(10));
      expect(d.update(400, at(25)), isFalse);
      expect(d.isOff, isFalse);
    });

    test('back on needs to be well inside, then it can alert again', () {
      final d = OffLoopDetector();
      d.update(400, at(0));
      d.update(400, at(20));
      d.update(120, at(30)); // between return and leave: still off
      expect(d.isOff, isTrue);
      d.update(30, at(40));
      expect(d.isOff, isFalse);
      d.update(400, at(50));
      expect(d.update(400, at(70)), isTrue);
    });
  });

  group('Google Maps link', () {
    String fmt(LatLng p) =>
        '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';

    test('3 stops in order, the main stop among them, back home', () {
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
      expect(stops, hasLength(3));
      expect(stops[1], anyOf(fmt(loop[61]), fmt(loop[62])));

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

    List<LatLng> stopsIn(Uri url) => [
      for (final s in url.queryParameters['waypoints']!.split('|'))
        LatLng(double.parse(s.split(',')[0]), double.parse(s.split(',')[1])),
    ];

    test('a main stop off the loop goes in as the loop point beside it', () {
      final offLoop = _d.offset(loop[60], 800, 0); // 800 m north of the edge
      final stops = stopsIn(googleMapsLink(route: loop, mainStop: offLoop));
      final middle = stops[1];
      expect(tracker.locate(middle).offRouteM, lessThan(1));
      expect(_d(middle, loop[60]), lessThan(150));
    });

    test('mid-ride: only the stops still ahead', () {
      final url = googleMapsLink(route: loop, fromAlongM: 7_000);
      final stops = stopsIn(url);
      expect(stops, hasLength(1)); // the one at 9 km
      expect(tracker.locate(stops.single).alongM, closeTo(9_000, 100));
      expect(url.queryParameters['destination'], fmt(loop.last));

      final nearlyHome = googleMapsLink(route: loop, fromAlongM: 11_000);
      expect(nearlyHome.queryParameters.containsKey('waypoints'), isFalse);
    });

    test('no highway avoidance unless asked', () {
      expect(
        googleMapsLink(route: loop).queryParameters.containsKey('avoid'),
        isFalse,
      );
    });
  });
}
