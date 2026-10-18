import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/data/models/generated_loop.dart';
import 'package:pasyarph/data/models/loop.dart';
import 'package:pasyarph/data/repositories/route_repository.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';
import 'package:pasyarph/features/ride/loop_stats.dart';
import 'package:pasyarph/features/ride/providers/loop_preview_provider.dart';

import '../../support/fake_services.dart';

final _request = LoopRequest(
  start: DemoRoutes.start,
  duration: LoopDuration.halfDay,
  avoidHighways: true,
  avoidUnpaved: false,
);

void main() {
  group('stats', () {
    test('curvy levels', () {
      expect(curvyLevel(80), CurvyLevel.low);
      expect(curvyLevel(150), CurvyLevel.medium);
      expect(curvyLevel(299), CurvyLevel.medium);
      expect(curvyLevel(300), CurvyLevel.high);
    });

    test('distance and ride time', () {
      expect(formatDistance(118400), '118 km');
      expect(formatDistance(8420), '8.4 km');
      expect(formatRideTime(13800), '3 h 50');
      expect(formatRideTime(14400), '4 h');
      expect(formatRideTime(3725), '1 h 02');
      expect(formatRideTime(2700), '45 min');
    });

    test('main stop is the farthest point, with km along the route', () {
      const a = LatLng(16.0, 121.0);
      const b = LatLng(16.1, 121.0); // ~11.1 km north
      const c = LatLng(16.2, 121.0); // farthest
      final stop = farthestPoint([a, b, c, b, a]);
      expect(stop.location, c);
      expect(stop.metersIn, closeTo(22132, 50));
      expect(stop.kmInLabel, '22 KM IN');
    });

    test('stop from the function: title, km, and detail', () {
      final stop = stopFor(demoLoop(mainStop: demoStop));
      expect(stop.title, 'Mt. Palali Viewpoint');
      expect(stop.kmInLabel, '52 KM IN');
      expect(stopDetail(stop, demoFuel), 'Viewpoint · gas station nearby');
      expect(stopDetail(stop, const []), 'Viewpoint');
    });

    test('unnamed place: its type is the title', () {
      final stop = stopFor(
        demoLoop(
          mainStop: MainStop(location: DemoRoutes.mainStop, type: 'waterfall'),
        ),
      );
      expect(stop.title, 'Waterfall');
      expect(stopDetail(stop, const []), '');
    });

    test('turnaround or no stop at all: the farthest point', () {
      final turnaround = stopFor(
        demoLoop(
          mainStop: MainStop(location: DemoRoutes.mainStop, type: 'turnaround'),
        ),
      );
      expect(turnaround.title, 'Main stop');
      expect(stopDetail(turnaround, const []), 'Farthest point of the loop');

      final none = stopFor(demoLoop());
      expect(none.location, DemoRoutes.mainStop);
      expect(none.title, 'Main stop');
    });

    test('fuel more than 3 km from the stop is not "nearby"', () {
      final stop = stopFor(demoLoop(mainStop: demoStop));
      final far = [FuelStop(location: DemoRoutes.start, name: 'Shell')];
      expect(stopDetail(stop, far), 'Viewpoint');
    });

    test('best loop: least backtracking, then curviest', () {
      final picked = pickBest([
        demoLoop(seed: 1, backtracking: 0.4),
        demoLoop(seed: 2, backtracking: 0.1, curviness: 100),
        demoLoop(seed: 3, backtracking: 0.105, curviness: 300),
      ]);
      expect(picked.seed, 3);
    });
  });

  group('LoopPreviewProvider', () {
    test('generate fills the loop and main stop', () async {
      final provider = LoopPreviewProvider(FakeRouteRepository());
      expect(await provider.generate(_request), isTrue);
      expect(provider.loop, isNotNull);
      expect(provider.mainStop!.location, DemoRoutes.mainStop);
      expect(provider.loading, isFalse);
    });

    test(
      'ride this loop: that loop, titled by name, no shuffle or reroll',
      () async {
        final repo = FakeRouteRepository([
          // Approach and return on the same road: high backtracking is fine.
          demoLoop(backtracking: 0.6, approachM: 4200),
        ]);
        final provider = LoopPreviewProvider(repo);
        expect(
          await provider.rideLoop(
            loopId: 'loop-1',
            name: 'Sunday Falls Loop',
            start: DemoRoutes.start,
          ),
          isTrue,
        );
        expect(repo.rideLoops, ['loop-1']);
        expect(repo.seeds, isEmpty);
        expect(provider.isRideThisLoop, isTrue);
        expect(provider.title, 'SUNDAY FALLS LOOP');
        expect(provider.loop!.approachM, 4200);
        expect(await provider.shuffle(), isFalse);
        expect(repo.rideLoops, hasLength(1));

        // Generating afterwards is a normal loop again.
        await provider.generate(_request);
        expect(provider.isRideThisLoop, isFalse);
        expect(provider.title, 'HALF-DAY LOOP');
      },
    );

    test('ride this loop: a private or deleted loop says so', () async {
      final provider = LoopPreviewProvider(
        FakeRouteRepository([
          const RouteException(
            'loop_not_found',
            "This loop isn't available anymore.",
          ),
        ]),
      );
      final ok = await provider.rideLoop(
        loopId: 'gone',
        name: 'Old loop',
        start: DemoRoutes.start,
      );
      expect(ok, isFalse);
      expect(provider.error!.code, 'loop_not_found');
    });

    test('backtracking loop: tries more seeds and keeps the best', () async {
      final repo = FakeRouteRepository([
        demoLoop(seed: 1, backtracking: 0.5),
        demoLoop(seed: 2, backtracking: 0.3),
        demoLoop(seed: 3, backtracking: 0.1),
      ]);
      final provider = LoopPreviewProvider(repo);
      await provider.generate(_request);
      expect(repo.seeds, hasLength(3)); // stopped once one was fine
      expect(provider.loop!.seed, 3);
    });

    test('at most 3 extra seeds, then the least bad', () async {
      final repo = FakeRouteRepository([
        for (var i = 1; i <= 5; i++)
          demoLoop(seed: i, backtracking: 0.3 + i / 100),
      ]);
      final provider = LoopPreviewProvider(repo);
      await provider.generate(_request);
      expect(repo.seeds, hasLength(4));
      expect(provider.loop!.seed, 1);
    });

    test('an error on a reroll keeps the loops already found', () async {
      final repo = FakeRouteRepository([
        demoLoop(seed: 1, backtracking: 0.5),
        RouteException.offline,
      ]);
      final provider = LoopPreviewProvider(repo);
      expect(await provider.generate(_request), isTrue);
      expect(provider.loop!.seed, 1);
    });

    test(
      'shuffle keeps the old loop visible until the new one arrives',
      () async {
        final repo = FakeRouteRepository();
        final provider = LoopPreviewProvider(repo);
        await provider.generate(_request);
        final first = provider.loop;

        repo.gate = Completer();
        final shuffled = provider.shuffle();
        expect(provider.loading, isTrue);
        expect(provider.loop, same(first));

        repo.gate!.complete();
        expect(await shuffled, isTrue);
        expect(provider.loop, isNot(same(first)));
        expect(repo.seeds[0], isNot(repo.seeds[1]));
      },
    );

    test('a failed shuffle keeps the loop and reports the error', () async {
      final repo = FakeRouteRepository();
      final provider = LoopPreviewProvider(repo);
      await provider.generate(_request);
      final first = provider.loop;

      repo.results.add(
        const RouteException('routing_busy', 'The route service is busy.'),
      );
      expect(await provider.shuffle(), isFalse);
      expect(provider.loop, same(first));
      expect(provider.error!.code, 'routing_busy');
    });

    test('generate failure leaves no loop', () async {
      final provider = LoopPreviewProvider(
        FakeRouteRepository([RouteException.offline]),
      );
      expect(await provider.generate(_request), isFalse);
      expect(provider.loop, isNull);
      expect(provider.error, RouteException.offline);
    });
  });
}
