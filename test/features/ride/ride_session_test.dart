import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/data/ids.dart';
import 'package:pasyarph/data/models/generated_loop.dart';
import 'package:pasyarph/data/repositories/ride_history_repository.dart';
import 'package:pasyarph/features/ride/loop_stats.dart';
import 'package:pasyarph/features/ride/providers/loop_preview_provider.dart';
import 'package:pasyarph/features/ride/providers/ride_session_provider.dart';

import '../../support/fake_services.dart';

const _d = Distance();

/// 12 km rectangle loop, a point every 100 m.
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
  TestWidgetsFlutterBinding.ensureInitialized();

  final route = _rectangle();
  final loop = GeneratedLoop(
    route: route,
    distanceM: 12000,
    durationS: 1800,
    steps: const [],
    seed: 1,
    backtrackingRatio: 0,
    curvinessScore: 100,
  );
  final stop = StopInfo(
    location: route[60],
    metersIn: 6000,
    name: 'Talon',
    type: 'waterfall',
  );
  final request = LoopRequest(
    start: route.first,
    duration: LoopDuration.quick,
    avoidHighways: true,
    avoidUnpaved: false,
  );

  late FakePositionSource gps;
  late LocationProvider location;
  late FakeRideNotifier notifier;
  late FakeRideHistory history;
  late List<Uri> opened;
  late DateTime now;
  late RideSessionProvider ride;

  setUp(() async {
    gps = FakePositionSource(last: RiderFix(point: route.first));
    location = LocationProvider(
      permissions: FakeLocationPermission(),
      positions: gps,
    );
    await location.start();
    notifier = FakeRideNotifier();
    history = FakeRideHistory();
    opened = [];
    now = DateTime(2026, 10, 18, 8);
    ride = RideSessionProvider(
      location: location,
      notifier: notifier,
      history: history,
      openUrl: (url) async {
        opened.add(url);
        return true;
      },
      clock: () => now,
      tickEvery: null,
    );
  });

  tearDown(() {
    ride.dispose();
    location.dispose();
  });

  /// Rides to route point [i] at [kmh], [seconds] after the last fix.
  Future<void> rideTo(int i, {double kmh = 40, int seconds = 30}) async {
    now = now.add(Duration(seconds: seconds));
    gps.emit(RiderFix(point: route[i], speedMps: kmh / 3.6));
    await Future<void>.delayed(Duration.zero);
  }

  test('start: tracking in the background, then Google Maps opens', () async {
    await ride.start(loop: loop, stop: stop, request: request);
    expect(ride.active, isTrue);
    expect(gps.background, isTrue);
    expect(notifier.events, ['prepare']);
    expect(opened.single.queryParameters['avoid'], 'highways');
  });

  test('a whole loop: stop alert, home alert, summary saved', () async {
    await ride.start(loop: loop, stop: stop, request: request);
    for (var i = 5; i <= 55; i += 5) {
      await rideTo(i);
    }
    expect(ride.toStopM, closeTo(500, 30));
    expect(ride.riddenM, closeTo(5500, 30));

    // Pull over at the waterfall: GPS goes quiet, the ticker notices.
    await rideTo(60, kmh: 3);
    now = now.add(const Duration(seconds: 25));
    ride.tick();
    expect(ride.reachedStop, isTrue);
    expect(notifier.events, contains('stop:Talon'));
    expect(ride.toStopM, isNull);

    for (var i = 65; i < route.length; i += 5) {
      await rideTo(i);
    }
    await rideTo(route.length - 1, kmh: 0);
    now = now.add(const Duration(seconds: 25));
    ride.tick();
    await pumpEventQueue(); // saving and alerts run after the tick

    expect(ride.phase, RidePhase.finished);
    expect(gps.background, isFalse);
    final saved = history.saved.single;
    expect(saved.reachedStop, isTrue);
    expect(saved.stopName, 'Talon');
    expect(saved.riddenM, closeTo(12000, 100));
    expect(notifier.events.last, startsWith('finished:12 km'));
  });

  test('stopping at home right after leaving does not end the ride', () async {
    await ride.start(loop: loop, stop: stop, request: request);
    await rideTo(3);
    await rideTo(0, kmh: 0);
    now = now.add(const Duration(seconds: 60));
    ride.tick();
    expect(ride.active, isTrue);
    expect(ride.atHome, isFalse);
  });

  test('a short ride away and back still offers FINISH RIDE', () async {
    await ride.start(loop: loop, stop: stop, request: request);
    await rideTo(12); // 1.2 km out, well short of half the loop
    await rideTo(1, kmh: 10);
    expect(ride.atHome, isTrue);
    expect(ride.active, isTrue); // not finished on its own
  });

  test('back home after the loop: one alert, then FINISH RIDE saves', () async {
    await ride.start(loop: loop, stop: stop, request: request);
    for (var i = 10; i <= 110; i += 10) {
      await rideTo(i);
    }
    expect(ride.atHome, isFalse); // 1 km out
    await rideTo(route.length - 2, kmh: 20, seconds: 10);
    await rideTo(route.length - 1, kmh: 10, seconds: 10);
    expect(ride.atHome, isTrue);
    expect(notifier.events.where((e) => e == 'home'), hasLength(1));

    await ride.end();
    expect(ride.phase, RidePhase.finished);
    expect(ride.atHome, isFalse);
    expect(history.saved, hasLength(1));
    expect(notifier.events.last, 'clear');
  });

  test('riding past the stop without stopping is not an arrival', () async {
    await ride.start(loop: loop, stop: stop, request: request);
    for (var i = 50; i <= 70; i++) {
      await rideTo(i, kmh: 35, seconds: 10);
    }
    expect(ride.reachedStop, isFalse);
  });

  /// Rides to [m] meters beside route point [i] (east of the west edge).
  Future<void> rideBeside(int i, double m, {int seconds = 15}) async {
    now = now.add(Duration(seconds: seconds));
    gps.emit(RiderFix(point: _d.offset(route[i], m, 270), speedMps: 10));
    await Future<void>.delayed(Duration.zero);
  }

  test('leaving the loop alerts once, coming back clears it', () async {
    await ride.start(loop: loop, stop: stop, request: request);
    await rideTo(10);
    await rideBeside(15, 400);
    expect(ride.offLoop, isFalse);
    await rideBeside(18, 500, seconds: 25);
    expect(ride.offLoop, isTrue);
    await rideBeside(20, 500);
    expect(notifier.events.where((e) => e == 'left'), hasLength(1));

    await rideTo(22);
    expect(ride.offLoop, isFalse);
    expect(notifier.events.last, 'back');
  });

  test('riding to a main stop off the loop is not leaving it', () async {
    final offStop = StopInfo(
      location: _d.offset(route[60], 1000, 0),
      metersIn: 6000,
      name: 'Talon',
      type: 'waterfall',
    );
    await ride.start(loop: loop, stop: offStop, request: request);
    await rideTo(60);
    for (var m = 200; m <= 1000; m += 200) {
      now = now.add(const Duration(seconds: 30));
      gps.emit(
        RiderFix(point: _d.offset(route[60], m.toDouble(), 0), speedMps: 8),
      );
      await Future<void>.delayed(Duration.zero);
    }
    expect(ride.offLoop, isFalse);
    expect(notifier.events, isNot(contains('left')));
  });

  test('the saved ride carries what posting needs', () async {
    await ride.start(loop: loop, stop: stop, request: request);
    for (var i = 10; i <= 60; i += 10) {
      await rideTo(i);
    }
    await ride.end();
    final saved = history.saved.single;
    expect(isId(saved.id), isTrue);
    expect(saved.route, route);
    expect(saved.preview, hasLength(RideSummary.previewPoints));
    expect(saved.stop!.name, 'Talon');
    expect(saved.stop!.type, 'waterfall');
    expect(saved.loopDurationS, 1800);
    expect(saved.canPost(now), isTrue); // 6 of 12 km ridden
    expect(ride.summary!.id, saved.id);
  });

  test('END RIDE saves what was ridden, without a "done" alert', () async {
    await ride.start(loop: loop, stop: stop, request: request);
    await rideTo(20);
    await ride.end();
    expect(ride.phase, RidePhase.finished);
    expect(history.saved.single.reachedStop, isFalse);
    expect(history.saved.single.riddenM, closeTo(2000, 30));
    expect(notifier.events.where((e) => e.startsWith('finished')), isEmpty);
    ride.close();
    expect(ride.phase, RidePhase.idle);
  });

  test('Google Maps missing: the session says so', () async {
    ride = RideSessionProvider(
      location: location,
      notifier: notifier,
      history: history,
      openUrl: (_) async => false,
      clock: () => now,
      tickEvery: null,
    );
    await ride.start(loop: loop, stop: stop, request: request);
    expect(ride.mapsOpened, isFalse);
    expect(ride.active, isTrue);
  });
}
