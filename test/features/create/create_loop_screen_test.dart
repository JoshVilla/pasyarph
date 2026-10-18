import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/core/map/map_markers.dart';
import 'package:pasyarph/core/widgets/widgets.dart';
import 'package:pasyarph/data/models/club.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/models/routed_leg.dart';
import 'package:pasyarph/features/create/providers/create_loop_controller.dart';
import 'package:pasyarph/features/create/screens/create_loop_screen.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';
import 'package:provider/provider.dart';

import '../../support/fake_services.dart';

/// Compare with design/screenshots/06-create-loop.png.
const _screen = BoxConstraints.tightFor(width: 390, height: 844);

final _club = Club(
  id: 'club-1',
  name: '[Club name]',
  ownerId: 'me',
  createdAt: DateTime(2026),
);

/// The mockup's loop: S → 1 → 2 → flag, back to S; 96 km, 3 h 10.
RoutedLeg _mockupLeg(LatLng a, LatLng b) {
  final r = DemoRoutes.created;
  final points = switch ((a, b)) {
    _ when a == DemoRoutes.start && b == DemoRoutes.point1 => [a, r[1], b],
    _ when a == DemoRoutes.mainStop && b == DemoRoutes.start =>
      DemoRoutes.closing,
    _ => [a, b],
  };
  return RoutedLeg(points: points, distanceM: 24000, durationS: 2850);
}

LocationProvider _location({double speedMps = 0}) => LocationProvider(
  permissions: FakeLocationPermission(),
  positions: FakePositionSource(
    last: RiderFix(point: DemoRoutes.start, speedMps: speedMps),
  ),
);

CreateLoopController _mockupLoop(FakeRouteRepository routes) =>
    CreateLoopController(
        routes: routes..legFor = _mockupLeg,
        loops: FakeLoopRepository(clubs: [_club]),
        debounce: Duration.zero,
      )
      ..setStart(DemoRoutes.start)
      ..addPoint(DemoRoutes.point1)
      ..addPoint(DemoRoutes.point2)
      ..addPoint(DemoRoutes.mainStop)
      ..setName('Sunday Falls Loop')
      ..setVisibility(LoopVisibility.club);

Widget _screenWith(
  CreateLoopController loop, {
  LocationProvider? location,
}) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: const EdgeInsets.only(top: 44),
      viewPadding: const EdgeInsets.only(top: 44),
    ),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: loop),
        ChangeNotifierProvider.value(value: location ?? _location()),
      ],
      child: const CreateLoopScreen(),
    ),
  ),
);

void main() {
  group('Golden', () {
    goldenTest(
      'Create a loop (06)',
      fileName: 'create_loop',
      constraints: _screen,
      pumpBeforeTest: (tester) async => tester.pumpAndSettle(),
      builder: () => _screenWith(_mockupLoop(FakeRouteRepository())),
    );
  });

  Future<CreateLoopController> pump(
    WidgetTester tester, {
    CreateLoopController? loop,
    LocationProvider? location,
    FakeLoopRepository? loops,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c =
        loop ??
        CreateLoopController(
          routes: FakeRouteRepository(),
          loops: loops ?? FakeLoopRepository(),
          debounce: Duration.zero,
        );
    await tester.pumpWidget(
      MaterialApp(home: _screenWith(c, location: location)),
    );
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('shows the mockup loop: stats, points and the main stop', (
    tester,
  ) async {
    await pump(tester, loop: _mockupLoop(FakeRouteRepository()));
    expect(find.text('Tap the map to add a point'), findsOneWidget);
    expect(find.text('96 km · 3 h 10'), findsOneWidget);
    expect(find.text('3 points · closes back to start'), findsOneWidget);
    expect(
      find.text('Only members of [Club name] will see this loop.'),
      findsOneWidget,
    );
    expect(find.byType(LoopPointMarker), findsNWidgets(3)); // S, 1, 2
    expect(find.byType(MainStopMarker), findsOneWidget);
  });

  testWidgets('starts at the rider, tapping the map adds points', (
    tester,
  ) async {
    final loop = await pump(tester);
    expect(loop.start, DemoRoutes.start);
    expect(find.text('0 km · 0 min'), findsOneWidget);
    expect(find.bySemanticsLabel('Undo last point'), findsNothing);

    await tester.tapAt(const Offset(100, 200));
    // The map waits out a possible double tap (zoom) first.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(loop.points, hasLength(1));
    expect(find.text('1 point · closes back to start'), findsOneWidget);
    expect(find.text('Tap a point for the main stop'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Undo last point'));
    await tester.pumpAndSettle();
    expect(loop.points, isEmpty);
  });

  testWidgets('hold a point to remove it, tap one for the main stop', (
    tester,
  ) async {
    final loop = await pump(tester, loop: _mockupLoop(FakeRouteRepository()));
    await tester.tap(find.bySemanticsLabel('Point 1'));
    await tester.pumpAndSettle();
    expect(loop.mainStopIndex, 0);

    await tester.longPress(find.bySemanticsLabel('Point 2'));
    await tester.pumpAndSettle();
    expect(loop.points, [DemoRoutes.point1, DemoRoutes.mainStop]);
  });

  testWidgets('SAVE stores the loop; SHARE LINK copies its link', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    final loops = FakeLoopRepository(clubs: [_club]);
    final loop = CreateLoopController(
      routes: FakeRouteRepository()..legFor = _mockupLeg,
      loops: loops,
      debounce: Duration.zero,
    )..createId = (() => 'loop-1');
    await pump(tester, loop: loop);
    loop
      ..addPoint(DemoRoutes.point1)
      ..addPoint(DemoRoutes.point2);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sunday Falls Loop');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(loops.saved['loop-1']!.name, 'Sunday Falls Loop');
    expect(find.text('Loop saved. Find it under Me.'), findsOneWidget);
    // Saved and unchanged: nothing to save.
    expect(
      tester.widget<SecondaryButton>(find.byType(SecondaryButton)).onPressed,
      isNull,
    );

    await tester.tap(find.text('SHARE LINK'));
    await tester.pumpAndSettle();
    expect(copied, ['https://pasyar.app/loop/loop-1']);
    expect(loops.calls, ['create:loop-1']);
  });

  testWidgets('no typing or saving while moving', (tester) async {
    await pump(
      tester,
      loop: _mockupLoop(FakeRouteRepository()),
      location: _location(speedMps: 8),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester.widget<SecondaryButton>(find.byType(SecondaryButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
  });

  testWidgets('Private turns SHARE LINK off', (tester) async {
    final loop = await pump(tester, loop: _mockupLoop(FakeRouteRepository()));
    await tester.tap(find.text('Private'));
    await tester.pumpAndSettle();
    expect(loop.visibility, LoopVisibility.private);
    expect(find.text('Only you will see this loop.'), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
  });
}
