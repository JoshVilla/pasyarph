import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/data/models/club.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/repositories/loop_repository.dart';
import 'package:pasyarph/data/repositories/route_repository.dart';
import 'package:pasyarph/features/create/loop_builder.dart';
import 'package:pasyarph/features/create/providers/create_loop_controller.dart';

import '../../support/fake_services.dart';

const s = LatLng(16.6, 121.4);
const p1 = LatLng(16.62, 121.4);
const p2 = LatLng(16.62, 121.43);
const p3 = LatLng(16.6, 121.45);

final club = Club(
  id: 'club-1',
  name: 'Cordon Riders',
  ownerId: 'me',
  createdAt: DateTime(2026),
);

void main() {
  late FakeRouteRepository routes;
  late FakeLoopRepository loops;
  late CreateLoopController c;

  CreateLoopController make({Duration debounce = Duration.zero}) =>
      CreateLoopController(routes: routes, loops: loops, debounce: debounce)
        ..createId = (() => 'loop-1')
        ..setStart(s);

  setUp(() {
    routes = FakeRouteRepository();
    loops = FakeLoopRepository(clubs: [club]);
    c = make();
  });

  Future<void> settle() => pumpEventQueue();

  test('S is the first fix; later fixes do not move it', () {
    c.setStart(p3);
    expect(c.start, s);
  });

  test('changes are routed once, 600 ms after the last one', () async {
    c = make(debounce: const Duration(milliseconds: 600));
    c
      ..addPoint(p1)
      ..addPoint(p2)
      ..addPoint(p3);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(routes.pointRuns, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await settle();
    expect(routes.pointRuns, [
      [
        [s, p1, p2, p3, s],
      ],
    ]);
    expect(c.totals.complete, isTrue);
  });

  test('only legs that changed are routed again', () async {
    c
      ..addPoint(p1)
      ..addPoint(p2);
    await settle();

    c.addPoint(p3); // p2 → p3 → S are new; p2 → S is no longer used.
    await settle();
    expect(routes.pointRuns.last, [
      [p2, p3, s],
    ]);

    // Undo brings back p2 → S, which is cached: no call.
    final calls = routes.pointRuns.length;
    c.undo();
    await settle();
    expect(routes.pointRuns.length, calls);
    expect(c.points, [p1, p2]);
    expect(c.totals.complete, isTrue);
  });

  test('dragging waits for the drop to route', () async {
    c
      ..addPoint(p1)
      ..addPoint(p2);
    await settle();
    final calls = routes.pointRuns.length;

    const moved = LatLng(16.63, 121.41);
    c.dragPoint(0, moved);
    await settle();
    expect(routes.pointRuns.length, calls);
    // Straight while dragging.
    expect(c.shape.dashed, anyElement(equals([s, moved])));

    c.endDrag();
    await settle();
    expect(routes.pointRuns.last, [
      [s, moved, p2],
    ]);
  });

  test('at most 15 points', () {
    for (var i = 0; i < 20; i++) {
      c.addPoint(LatLng(16.6 + i * 0.001, 121.41));
    }
    expect(c.points, hasLength(maxLoopPoints));
    expect(c.canAddPoint, isFalse);
  });

  test('main stop: farthest point, the rider pick, kept on removals', () {
    c
      ..addPoint(p1)
      ..addPoint(p2)
      ..addPoint(p3);
    expect(c.mainStopIndex, 2); // p3 is farthest from S

    c.setMainStop(1);
    c.removePoint(0);
    expect(c.mainStopIndex, 0); // still p2
    expect(c.points[c.mainStopIndex!], p2);

    c.removePoint(0); // the main stop itself: back to the default
    expect(c.mainStopIndex, 0);
  });

  test('routing errors are kept until the next change or retry', () async {
    routes.failRouteNext = const RouteException('off_road', 'Too far.');
    c
      ..addPoint(p1)
      ..addPoint(p2);
    await settle();
    expect(c.routeError?.code, 'off_road');
    expect(c.canSave, isFalse);

    c.retryRoute();
    await settle();
    expect(c.routeError, isNull);
    expect(c.totals.complete, isTrue);
  });

  group('save', () {
    Future<void> drawLoop() async {
      c
        ..addPoint(p1)
        ..addPoint(p2)
        ..addPoint(p3)
        ..setName('  Sunday Falls Loop ');
      await settle();
    }

    test('needs two points and every leg routed', () async {
      c.addPoint(p1);
      await settle();
      expect(c.canSave, isFalse);
      c.addPoint(p2);
      expect(c.canSave, isFalse); // routing
      await settle();
      expect(c.canSave, isTrue);
    });

    test('inserts a custom loop, then updates it', () async {
      await drawLoop();
      expect(await c.save(), isTrue);
      final saved = loops.saved['loop-1']!;
      expect(saved.name, 'Sunday Falls Loop');
      expect(saved.source, LoopSource.custom);
      expect(saved.route.first, s);
      expect(saved.route.last, s);
      expect(saved.distanceM, c.totals.distanceM);
      expect(saved.mainStop!.location, p3);
      expect(saved.mainStop!.type, customStopType);
      expect(saved.mainStop!.kmIntoRoute, greaterThan(0));
      expect(saved.visibility, LoopVisibility.public);
      expect(c.dirty, isFalse);

      c.setName('Renamed');
      expect(c.dirty, isTrue);
      await c.save();
      expect(loops.calls, ['create:loop-1', 'update:loop-1']);
      expect(loops.saved['loop-1']!.name, 'Renamed');
    });

    test('a loop without a name gets one from its length', () async {
      await drawLoop();
      c.setName(' ');
      await c.save();
      expect(loops.saved['loop-1']!.name, endsWith(' km loop'));
    });

    test('Group shares with the first club', () async {
      await drawLoop();
      c.setVisibility(LoopVisibility.club);
      expect(c.canSave, isFalse); // clubs loading
      await settle();
      expect(c.club, club);
      await c.save();
      expect(loops.saved['loop-1']!.visibility, LoopVisibility.club);
      expect(loops.saved['loop-1']!.clubId, 'club-1');
    });

    test('Group without clubs cannot be saved', () async {
      loops.clubs.clear();
      await drawLoop();
      c.setVisibility(LoopVisibility.club);
      await settle();
      expect(c.clubs, isEmpty);
      expect(c.canSave, isFalse);
    });

    test('a failed save keeps the loop and reports why', () async {
      await drawLoop();
      loops.failNext = LoopException.saveFailed;
      expect(await c.save(), isFalse);
      expect(c.saveError, LoopException.saveFailed);
      expect(c.savedId, isNull);
      expect(c.dirty, isTrue);
    });
  });

  group('share link', () {
    test('saves first, then links the loop', () async {
      c
        ..addPoint(p1)
        ..addPoint(p2);
      await settle();
      final link = await c.shareLink();
      expect(link.toString(), 'https://pasyar.app/loop/loop-1');
      expect(loops.calls, ['create:loop-1']);

      // Unchanged: no second save.
      await c.shareLink();
      expect(loops.calls, ['create:loop-1']);
    });

    test('private loops have no link', () async {
      c
        ..addPoint(p1)
        ..addPoint(p2)
        ..setVisibility(LoopVisibility.private);
      await settle();
      expect(c.canShareNow, isFalse);
      expect(await c.shareLink(), isNull);
      expect(loops.calls, isEmpty);
    });
  });
}
