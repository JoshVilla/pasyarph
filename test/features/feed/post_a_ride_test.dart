import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/router.dart';
import 'package:pasyarph/data/ids.dart';
import 'package:pasyarph/data/repositories/ride_history_repository.dart';
import 'package:pasyarph/features/feed/post_a_ride.dart';
import 'package:provider/provider.dart';

import '../../support/fake_services.dart';

RideSummary _ride(String stop, {bool posted = false}) => RideSummary(
  id: newId(),
  startedAt: DateTime.now().subtract(const Duration(hours: 4)),
  endedAt: DateTime.now().subtract(const Duration(hours: 1)),
  riddenM: 40000,
  loopM: 50000,
  stop: RideStop(
    location: const LatLng(16.7, 121.46),
    type: 'falls',
    name: stop,
  ),
  reachedStop: true,
  synced: true,
  posted: posted,
);

/// A page with a "post" button, and stand-ins for where it goes.
Widget _app(FakeRideHistory history) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () => postARide(context),
                child: const Text('post'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: Routes.postRide,
        builder: (_, s) => Text('posting ${s.pathParameters['rideId']}'),
      ),
      GoRoute(path: Routes.ride, builder: (_, _) => const Text('ride tab')),
    ],
  );
  return Provider<RideHistoryRepository>.value(
    value: history,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('no ride to post: says why, RIDE opens the Ride tab', (
    tester,
  ) async {
    final history = FakeRideHistory();
    await history.save(_ride('Talon', posted: true));
    await tester.pumpWidget(_app(history));
    await tester.tap(find.text('post'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No rides to post yet'), findsOneWidget);

    await tester.tap(find.text('RIDE'));
    await tester.pumpAndSettle();
    expect(find.text('ride tab'), findsOneWidget);
  });

  testWidgets('one ride to post: straight to it', (tester) async {
    final history = FakeRideHistory();
    final ride = _ride('Talon');
    await history.save(ride);
    await tester.pumpWidget(_app(history));
    await tester.tap(find.text('post'));
    await tester.pumpAndSettle();
    expect(find.text('posting ${ride.id}'), findsOneWidget);
  });

  testWidgets('several: pick which ride', (tester) async {
    final history = FakeRideHistory();
    final older = _ride('Talon');
    await history.save(older);
    await history.save(_ride('Bangaan View'));
    await tester.pumpWidget(_app(history));
    await tester.tap(find.text('post'));
    await tester.pumpAndSettle();
    expect(find.text('Which ride?'), findsOneWidget);
    expect(find.textContaining('Bangaan View · '), findsOneWidget);

    await tester.tap(find.textContaining('Talon · '));
    await tester.pumpAndSettle();
    expect(find.text('posting ${older.id}'), findsOneWidget);
  });
}
