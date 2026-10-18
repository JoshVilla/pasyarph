import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/data/models/generated_loop.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';
import 'package:pasyarph/features/ride/loop_stats.dart';
import 'package:pasyarph/features/ride/providers/loop_preview_provider.dart';
import 'package:pasyarph/features/ride/providers/ride_session_provider.dart';
import 'package:pasyarph/features/ride/screens/ride_session_screen.dart';
import 'package:provider/provider.dart';

import '../../support/fake_services.dart';

const _screen = BoxConstraints.tightFor(width: 390, height: 844);

/// A ride a third of the way round the mockup loop.
Future<RideSessionProvider> _ride() async {
  final gps = FakePositionSource(last: RiderFix(point: DemoRoutes.start));
  final location = LocationProvider(
    permissions: FakeLocationPermission(),
    positions: gps,
  );
  await location.start();
  final loop = demoLoop(mainStop: demoStop, fuel: demoFuel);
  final ride = RideSessionProvider(
    location: location,
    notifier: FakeRideNotifier(),
    history: FakeRideHistory(),
    openUrl: (_) async => true,
    clock: () => DateTime(2026, 10, 18, 9),
    tickEvery: null,
  );
  await ride.start(
    loop: loop,
    stop: stopFor(loop),
    request: LoopRequest(
      start: DemoRoutes.start,
      duration: LoopDuration.halfDay,
      avoidHighways: true,
      avoidUnpaved: false,
    ),
  );
  for (final p in DemoRoutes.ridden) {
    gps.emit(RiderFix(point: p, speedMps: 11));
    await Future<void>.delayed(Duration.zero);
  }
  return ride;
}

Widget _screenWith(RideSessionProvider ride) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: const EdgeInsets.only(top: 44),
      viewPadding: const EdgeInsets.only(top: 44),
    ),
    child: ChangeNotifierProvider.value(
      value: ride,
      child: const RideSessionScreen(),
    ),
  ),
);

void main() {
  late RideSessionProvider ride;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    ride = await _ride();
  });

  group('Golden', () {
    goldenTest(
      'Ride in progress',
      fileName: 'ride_session',
      constraints: _screen,
      pumpBeforeTest: (tester) async => tester.pumpAndSettle(),
      builder: () => _screenWith(ride),
    );
  });

  testWidgets('shows distance to the stop and ridden so far', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _screenWith(ride)));
    await tester.pumpAndSettle();
    expect(find.text('RIDE IN PROGRESS'), findsOneWidget);
    expect(find.textContaining('TO GO'), findsOneWidget);
    expect(find.text('Mt. Palali Viewpoint'), findsOneWidget);
    expect(find.text('40 km/h'), findsOneWidget);
  });
}
