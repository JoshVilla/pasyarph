import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/core/router.dart';
import 'package:pasyarph/core/theme/pasyar_theme.dart';
import 'package:pasyarph/data/repositories/discovery_repository.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';
import 'package:pasyarph/features/discover/screens/discover_screen.dart';
import 'package:pasyarph/features/ride/providers/loop_preview_provider.dart';
import '../../support/fake_discovery.dart';
import '../../support/fake_services.dart';

class World {
  final repo = FakeDiscoveryRepository([
    discoveryLoop('tanay', name: 'Tanay mountain loop'),
    discoveryLoop(
      'baguio',
      name: 'Baguio coffee ride',
      province: 'Benguet',
      distance: 34000,
      duration: 5400,
    ),
    discoveryLoop(
      'coast',
      name: 'Coastal weekend',
      province: 'Quezon',
      distance: 180000,
      duration: 18000,
    ),
  ]);
  final routes = FakeRouteRepository();
  final location = LocationProvider(
    permissions: FakeLocationPermission(),
    positions: FakePositionSource(last: RiderFix(point: DemoRoutes.start)),
  );
  late final router = GoRouter(
    initialLocation: Routes.discover,
    routes: [
      GoRoute(path: Routes.discover, builder: (_, _) => const DiscoverScreen()),
      GoRoute(
        path: Routes.loopPreview,
        builder: (_, _) => const Scaffold(body: Text('Route preview ready')),
      ),
    ],
  );
  Widget app({bool dark = false}) => MultiProvider(
    providers: [
      Provider<DiscoveryRepository>.value(value: repo),
      ChangeNotifierProvider.value(value: location),
      ChangeNotifierProvider(create: (_) => LoopPreviewProvider(routes)),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: PasyarTheme.light(),
      darkTheme: PasyarTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    ),
  );
}

Future<World> pump(
  WidgetTester tester, {
  World? world,
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final w = world ?? World();
  await w.location.start();
  await tester.pumpWidget(w.app(dark: dark));
  await tester.pumpAndSettle();
  addTearDown(w.router.dispose);
  addTearDown(w.location.dispose);
  return w;
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('Golden', () {
    for (final dark in [false, true]) {
      goldenTest(
        'Explore loops, ${dark ? 'Midnight Blue' : 'light'}',
        fileName: dark ? 'discover_dark' : 'discover',
        constraints: const BoxConstraints.tightFor(width: 390, height: 844),
        pumpBeforeTest: (tester) async => tester.pumpAndSettle(),
        builder: () => World().app(dark: dark),
      );
    }
  });

  testWidgets('searches destinations and clears combined filters', (
    tester,
  ) async {
    final w = await pump(tester);
    await tester.enterText(find.byType(TextField), 'Tanay');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(w.repo.calls.last.$1.term, 'Tanay');
    expect(find.text('Tanay mountain loop'), findsOneWidget);
    await tester.tap(find.text('Any distance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Under 50 km').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('No routes match yet'));
    expect(w.repo.calls.last.$1.distance, DiscoveryDistance.short);
    await tester.tap(find.text('Show all routes'));
    await tester.pumpAndSettle();
    expect(w.repo.calls.last.$1.term, isEmpty);
    expect(w.repo.calls.last.$1.distance, DiscoveryDistance.any);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('ride-time filtering and sorting reach the repository', (
    tester,
  ) async {
    final w = await pump(tester);
    await tester.tap(find.text('Any ride time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Under 2 hours').last);
    await tester.pumpAndSettle();
    expect(w.repo.calls.last.$1.time, DiscoveryTime.short);
    expect(find.text('Baguio coffee ride'), findsOneWidget);
    expect(find.text('Tanay mountain loop'), findsNothing);
    await tester.tap(find.text('Newest first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shortest distance').last);
    await tester.pumpAndSettle();
    expect(w.repo.calls.last.$1.sort, DiscoverySort.distance);
  });

  testWidgets('errors can be retried without losing filters', (tester) async {
    final w = World()..repo.fail = true;
    await pump(tester, world: w);
    await reveal(tester, find.text('Try again'));
    w.repo.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Tanay mountain loop'), findsOneWidget);
  });

  testWidgets('loads another page and opens the existing ride preview', (
    tester,
  ) async {
    final w = World()..repo.pageSize = 1;
    await pump(tester, world: w);
    await reveal(tester, find.text('Load more routes'));
    await tester.tap(find.text('Load more routes'));
    await tester.pumpAndSettle();
    expect(w.repo.calls.last.$2, 1);
    final card = find.bySemanticsLabel(RegExp(r'^Preview Baguio coffee ride,'));
    await reveal(tester, card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(w.routes.rideLoops, ['baguio']);
    expect(find.text('Route preview ready'), findsOneWidget);
  });

  testWidgets('narrow dark screen supports large text', (tester) async {
    await pump(tester, dark: true);
    tester.view.physicalSize = const Size(320, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await reveal(tester, find.text('Tanay mountain loop'));
    expect(tester.takeException(), isNull);
  });
}
