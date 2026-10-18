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
      builder: () => _screenWith(_preview(FakeRouteRepository())),
    );
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
