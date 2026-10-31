import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/core/router.dart';
import 'package:pasyarph/core/widgets/widgets.dart';
import 'package:pasyarph/data/models/club.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/repositories/loop_repository.dart';
import 'package:pasyarph/data/repositories/post_repository.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';
import 'package:pasyarph/features/post/screens/write_post_screen.dart';
import 'package:provider/provider.dart';

import '../../support/fake_post.dart';
import '../../support/fake_services.dart';

final _club = Club(
  id: 'k1',
  name: 'Iloilo Riders',
  ownerId: 'u',
  createdAt: DateTime(2026, 10, 1),
);

/// A home page that opens the screen and shows what it popped.
Future<Widget> _app(FakePosts posts, {bool moving = false}) async {
  final location = LocationProvider(
    permissions: FakeLocationPermission(),
    positions: FakePositionSource(
      last: RiderFix(point: DemoRoutes.start, speedMps: moving ? 8 : 0),
    ),
  );
  await location.start();
  LoopVisibility? result;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () async {
                    final v = await context.push<LoopVisibility>(
                      Routes.writePost,
                    );
                    setState(() => result = v);
                  },
                  child: const Text('write'),
                ),
                Text('posted: ${result?.name}'),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: Routes.writePost,
        builder: (_, _) => WritePostScreen(
          pick: ({required camera, required max}) async => [],
        ),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      Provider<PostRepository>.value(value: posts),
      Provider<LoopRepository>.value(value: FakeLoopRepository(clubs: [_club])),
      ChangeNotifierProvider.value(value: location),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// A 390 x 844 phone.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// Scrolls [finder] into view, then taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

PrimaryButton _postButton(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'POST'));

void main() {
  testWidgets('write, post publicly, and come back with where it went', (
    tester,
  ) async {
    _phone(tester);
    final posts = FakePosts();
    await tester.pumpWidget(await tester.runAsync(() => _app(posts)) as Widget);
    await tester.tap(find.text('write'));
    await tester.pumpAndSettle();

    expect(find.text('WRITE A POST'), findsOneWidget);
    expect(find.text('Photos (optional)'), findsOneWidget);
    expect(_postButton(tester).onPressed, isNull);

    await tester.enterText(
      find.byType(TextField),
      'Is the road to Daranak open?',
    );
    await tester.pump();
    await _tap(tester, find.text('POST'));
    await tester.pumpAndSettle();

    expect(posts.created.single['text'], 'Is the road to Daranak open?');
    expect(posts.created.single['visibility'], LoopVisibility.public);
    expect(find.text('posted: public'), findsOneWidget);
  });

  testWidgets('Group asks which club', (tester) async {
    _phone(tester);
    final posts = FakePosts();
    await tester.pumpWidget(await tester.runAsync(() => _app(posts)) as Widget);
    await tester.tap(find.text('write'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Meetup at 6');

    await _tap(tester, find.text('Group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iloilo Riders'));
    await tester.pumpAndSettle();
    expect(find.text('ILOILO RIDERS'), findsOneWidget);
    expect(
      find.text('Only members of Iloilo Riders will see it.'),
      findsOneWidget,
    );

    await _tap(tester, find.text('POST'));
    await tester.pumpAndSettle();
    expect(posts.created.single['clubId'], 'k1');
    expect(find.text('posted: club'), findsOneWidget);
  });

  testWidgets('moving: no typing or posting', (tester) async {
    _phone(tester);
    final posts = FakePosts();
    await tester.pumpWidget(
      await tester.runAsync(() => _app(posts, moving: true)) as Widget,
    );
    await tester.tap(find.text('write'));
    await tester.pumpAndSettle();
    expect(find.text('Stop riding to write and post.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    expect(_postButton(tester).onPressed, isNull);
  });
}
