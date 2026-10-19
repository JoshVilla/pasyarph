import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/location/location_permission.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/core/map/map_markers.dart';
import 'package:pasyarph/core/widgets/widgets.dart';
import 'package:pasyarph/data/models/generated_loop.dart';
import 'package:pasyarph/data/repositories/route_repository.dart';
import 'package:pasyarph/features/ride/providers/loop_preview_provider.dart';
import 'package:pasyarph/features/ride/providers/ride_options_provider.dart';
import 'package:pasyarph/features/ride/providers/ride_session_provider.dart';
import 'package:pasyarph/features/ride/screens/ride_screen.dart';
import 'package:pasyarph/features/ride/widgets/home_controls.dart';
import 'package:provider/provider.dart';

import '../../support/fake_services.dart';

/// Compare with design/screenshots/01-home.png.
const _screen = BoxConstraints.tightFor(width: 390, height: 844);
const _cordon = LatLng(16.6720, 121.4570);

/// Ride tab as it appears in the app: status bar inset on top, tabs below.
Widget _home(LocationProvider location, [FakeRouteRepository? routes]) {
  return Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 44),
        viewPadding: const EdgeInsets.only(top: 44),
      ),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: location),
          ChangeNotifierProvider(
            create: (_) => LoopPreviewProvider(routes ?? FakeRouteRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => RideSessionProvider(
              location: location,
              notifier: FakeRideNotifier(),
              history: FakeRideHistory(),
              tickEvery: null,
            ),
          ),
        ],
        child: Scaffold(
          body: const RideScreen(),
          bottomNavigationBar: PasyarBottomTabs(currentIndex: 0, onTap: (_) {}),
        ),
      ),
    ),
  );
}

LocationProvider _location({
  LocationAccess access = LocationAccess.granted,
  RiderFix? last = const RiderFix(point: _cordon),
}) => LocationProvider(
  permissions: FakeLocationPermission(access),
  positions: FakePositionSource(last: last),
);

PrimaryButton _generate(WidgetTester tester) => tester.widget<PrimaryButton>(
  find.byWidgetPredicate(
    (w) => w is PrimaryButton && w.label == 'GENERATE LOOP',
  ),
);

void main() {
  group('Golden', () {
    goldenTest(
      'Home (01)',
      fileName: 'home',
      constraints: _screen,
      pumpBeforeTest: (tester) async => tester.pumpAndSettle(),
      builder: () => _home(_location()),
    );

    goldenTest(
      'Home, location off',
      fileName: 'home_location_off',
      constraints: _screen,
      pumpBeforeTest: (tester) async => tester.pumpAndSettle(),
      builder: () => _home(_location(access: LocationAccess.denied)),
    );
  });

  testWidgets('shows the rider and enables GENERATE LOOP', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _home(_location())));
    await tester.pumpAndSettle();

    expect(find.byType(RiderDot), findsOneWidget);
    expect(find.byType(LocationOffBanner), findsNothing);
    expect(_generate(tester).onPressed, isNotNull);
  });

  testWidgets('no permission: banner, and GENERATE LOOP disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: _home(_location(access: LocationAccess.denied))),
    );
    await tester.pumpAndSettle();

    expect(find.text('ALLOW LOCATION'), findsOneWidget);
    expect(_generate(tester).onPressed, isNull);
  });

  testWidgets('denied forever: banner offers OPEN SETTINGS', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: _home(_location(access: LocationAccess.deniedForever))),
    );
    await tester.pumpAndSettle();
    expect(find.text('OPEN SETTINGS'), findsOneWidget);
  });

  testWidgets('GENERATE LOOP shows progress on the map', (tester) async {
    final routes = FakeRouteRepository()..gate = Completer();
    await tester.pumpWidget(MaterialApp(home: _home(_location(), routes)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GENERATE LOOP'));
    await tester.pump();
    expect(find.text('Building your loop…'), findsOneWidget);
    expect(_generate(tester).loading, isTrue);
    // Left pending: finishing would open the preview, which needs a router
    // (covered in widget_test.dart).
    expect(routes.seeds, hasLength(1));
  });

  testWidgets('a failed Generate explains why on the map', (tester) async {
    final routes = FakeRouteRepository([
      const RouteException('no_route', "Couldn't find a loop from here."),
    ]);
    await tester.pumpWidget(MaterialApp(home: _home(_location(), routes)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GENERATE LOOP'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't find a loop from here."), findsOneWidget);
    expect(_generate(tester).loading, isFalse);
  });

  testWidgets('duration and toggles update the options', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _home(_location())));
    await tester.pumpAndSettle();
    final options = Provider.of<RideOptionsProvider>(
      tester.element(find.text('QUICK')),
      listen: false,
    );
    expect(options.duration, LoopDuration.halfDay);

    await tester.tap(find.text('QUICK'));
    await tester.tap(find.text('Avoid unpaved'));
    await tester.tap(find.text('Avoid highways'));
    await tester.pump();
    expect(options.duration, LoopDuration.quick);
    expect(options.avoidUnpaved, isTrue);
    expect(options.avoidHighways, isFalse);
  });

  testWidgets('MULTI-DAY asks how many days and sends them', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Held open: the preview opens via the router (widget_test.dart).
    final routes = FakeRouteRepository()..gate = Completer();
    await tester.pumpWidget(MaterialApp(home: _home(_location(), routes)));
    await tester.pumpAndSettle();
    expect(find.text('Days'), findsNothing);

    await tester.tap(find.text('MULTI-DAY'));
    await tester.pumpAndSettle();
    expect(find.text('Days'), findsOneWidget);
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GENERATE LOOP'));
    await tester.pump();
    expect(routes.sentDays, [5]);
  });

  testWidgets('other durations send no days', (tester) async {
    final routes = FakeRouteRepository()..gate = Completer();
    await tester.pumpWidget(MaterialApp(home: _home(_location(), routes)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GENERATE LOOP'));
    await tester.pump();
    expect(routes.sentDays, [null]);
  });
}