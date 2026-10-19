import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/core/map/map_markers.dart';
import 'package:pasyarph/core/widgets/widgets.dart';
import 'package:pasyarph/data/models/generated_loop.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';
import 'package:pasyarph/features/ride/loop_stats.dart';
import 'package:pasyarph/features/ride/providers/loop_preview_provider.dart';
import 'package:pasyarph/features/ride/screens/loop_preview_screen.dart';
import 'package:pasyarph/features/ride/widgets/home_controls.dart';
import 'package:provider/provider.dart';

import '../../support/fake_services.dart';

/// Compare with design/screenshots/02-loop-preview.png.
const _screen = BoxConstraints.tightFor(width: 390, height: 844);

final _request = LoopRequest(
  start: DemoRoutes.start,
  duration: LoopDuration.halfDay,
  avoidHighways: true,
  avoidUnpaved: false,
);

LoopPreviewProvider _preview(FakeRouteRepository repo) =>
    LoopPreviewProvider(repo)..generate(_request);

Widget _screenWith(LoopPreviewProvider preview) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      padding: const EdgeInsets.only(top: 44),
      viewPadding: const EdgeInsets.only(top: 44),
    ),
    child: ChangeNotifierProvider.value(
      value: preview,
      child: const LoopPreviewScreen(),
    ),
  ),
);

void main() {
  group('Golden', () {
    goldenTest(
      'Loop preview (02)',
      fileName: 'loop_preview',
      constraints: _screen,
      pumpBeforeTest: (tester) async => tester.pumpAndSettle(),
      builder: () => _screenWith(
        _preview(
          FakeRouteRepository([demoLoop(mainStop: demoStop, fuel: demoFuel)]),
        ),
      ),
    );
  });

  testWidgets('multi-day: title by days, overnight stops, one try', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final base = demoLoop(backtracking: 0.5);
    final repo = FakeRouteRepository([
      GeneratedLoop(
        route: base.route,
        distanceM: 1380000,
        durationS: 90000,
        steps: const [],
        seed: 4,
        // Would be rerolled for a day loop; a multi-day loop costs too much.
        backtrackingRatio: 0.5,
        curvinessScore: 200,
        overnights: [
          Overnight(name: 'Baguio', location: DemoRoutes.point1, kmIntoRoute: 251),
          Overnight(name: 'Vigan', location: DemoRoutes.point2, kmIntoRoute: 520),
        ],
      ),
    ]);
    final preview = LoopPreviewProvider(repo)
      ..generate(
        LoopRequest(
          start: DemoRoutes.start,
          duration: LoopDuration.multiDay,
          avoidHighways: false,
          avoidUnpaved: false,
          days: 5,
        ),
      );
    await tester.pumpWidget(MaterialApp(home: _screenWith(preview)));
    await tester.pumpAndSettle();

    expect(find.text('5-DAY LOOP'), findsOneWidget);
    expect(find.text('OVERNIGHT STOPS'), findsOneWidget);
    expect(find.text('Night 1 · Baguio'), findsOneWidget);
    expect(find.text('520 km in'), findsOneWidget);
    expect(find.byType(LoopPointMarker), findsNWidgets(2));
    expect(repo.seeds, hasLength(1));
    expect(repo.sentDays, [5]);
  });

  testWidgets('shows stats, main stop and the loop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: _screenWith(_preview(FakeRouteRepository()))),
    );
    await tester.pumpAndSettle();

    expect(find.text('HALF-DAY LOOP'), findsOneWidget);
    expect(find.text('118 km'), findsOneWidget);
    expect(find.text('3 h 50'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    final kmIn = farthestPoint(DemoRoutes.loop).kmInLabel;
    expect(find.text('MAIN STOP · $kmIn'), findsOneWidget);
    expect(find.byType(MainStopMarker), findsOneWidget);
  });

  testWidgets('real stop: name, km, detail and fuel on the map', (
    tester,
  ) async {
    final repo = FakeRouteRepository([
      demoLoop(mainStop: demoStop, fuel: demoFuel),
    ]);
    await tester.pumpWidget(MaterialApp(home: _screenWith(_preview(repo))));
    await tester.pumpAndSettle();

    expect(find.text('MAIN STOP · 52 KM IN'), findsOneWidget);
    expect(find.text('Mt. Palali Viewpoint'), findsOneWidget);
    expect(find.text('Viewpoint · gas station nearby'), findsOneWidget);
    expect(find.byType(FuelMarker), findsOneWidget);
  });

  testWidgets('shuffle shows progress, then the new loop', (tester) async {
    final repo = FakeRouteRepository();
    final preview = _preview(repo);
    await tester.pumpWidget(MaterialApp(home: _screenWith(preview)));
    await tester.pumpAndSettle();

    repo.gate = Completer();
    repo.results.add(demoLoop(seed: 2, curviness: 100));
    await tester.tap(find.text('SHUFFLE'));
    await tester.pump();
    expect(find.text('Finding another loop…'), findsOneWidget);
    expect(find.text('High'), findsOneWidget); // old loop still shown

    repo.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Low'), findsOneWidget);
    expect(find.byType(MapNotice), findsNothing);
  });

  testWidgets('warnings from the function are shown', (tester) async {
    final repo = FakeRouteRepository([
      demoLoop(warnings: ['This loop uses an expressway for about 8 km.']),
    ]);
    await tester.pumpWidget(MaterialApp(home: _screenWith(_preview(repo))));
    await tester.pumpAndSettle();
    expect(
      find.text('This loop uses an expressway for about 8 km.'),
      findsOneWidget,
    );
  });

  testWidgets('START RIDE is ready, SHUFFLE is outlined', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: _screenWith(_preview(FakeRouteRepository()))),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SecondaryButton, 'SHUFFLE'), findsOneWidget);
    expect(
      tester
          .widget<PrimaryButton>(
            find.widgetWithText(PrimaryButton, 'START RIDE'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
