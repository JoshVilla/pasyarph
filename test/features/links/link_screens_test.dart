import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasyarph/core/location/location_permission.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/core/router.dart';
import 'package:pasyarph/core/share.dart';
import 'package:pasyarph/data/models/link_preview.dart';
import 'package:pasyarph/data/repositories/feed_repository.dart';
import 'package:pasyarph/data/repositories/link_repository.dart';
import 'package:pasyarph/data/repositories/social_repository.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';
import 'package:pasyarph/features/feed/providers/feed_provider.dart';
import 'package:pasyarph/features/links/screens/loop_link_screen.dart';
import 'package:pasyarph/features/links/screens/post_link_screen.dart';
import 'package:pasyarph/features/ride/providers/loop_preview_provider.dart';
import 'package:provider/provider.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_links.dart';
import '../../support/fake_services.dart';
import '../../support/fake_social.dart';

const _loopId = 'loop-1';
const _postId = 'post-1';
final _now = DateTime(2026, 10, 24, 9);

const _okLoop = LinkPreview(
  status: LinkStatus.ok,
  loopId: _loopId,
  name: 'Tanay Sunrise Loop',
  distanceM: 82000,
);
const _clubLoop = LinkPreview(
  status: LinkStatus.club,
  clubName: 'Rizal Riders',
);

LocationProvider _location({bool withFix = true, bool allowed = true}) =>
    LocationProvider(
      permissions: FakeLocationPermission(
        allowed ? LocationAccess.granted : LocationAccess.denied,
      ),
      positions: FakePositionSource(
        last: withFix ? RiderFix(point: DemoRoutes.start) : null,
      ),
    );

/// The link screens with a router like the app's: the link, the loop
/// preview, and Home.
Widget _app({
  required String initial,
  required FakeLinkRepository links,
  FakeRouteRepository? routes,
  FakeFeedRepository? feed,
  LocationProvider? location,
}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: Routes.loopLinkPath,
        builder: (context, state) => LoopLinkScreen(
          loopId: state.pathParameters['loopId']!,
          fixTimeout: Duration.zero,
        ),
      ),
      GoRoute(
        path: Routes.postLinkPath,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => FeedProvider(
            feed: context.read<FeedRepository>(),
            social: context.read<SocialRepository>(),
            location: context.read<LocationProvider>(),
            scope: FeedScope.post(state.pathParameters['postId']!),
          ),
          child: PostLinkScreen(
            postId: state.pathParameters['postId']!,
            clock: () => _now,
          ),
        ),
      ),
      GoRoute(
        path: Routes.loopPreview,
        builder: (context, state) => Scaffold(
          body: Text('PREVIEW ${context.read<LoopPreviewProvider>().title}'),
        ),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const Scaffold(body: Text('HOME')),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      Provider<LinkRepository>.value(value: links),
      Provider<Sharer>.value(value: FakeSharer()),
      Provider<FeedRepository>.value(value: feed ?? FakeFeedRepository([])),
      Provider<SocialRepository>.value(value: FakeSocialRepository()),
      ChangeNotifierProvider.value(value: location ?? _location()),
      ChangeNotifierProvider(
        create: (_) => LoopPreviewProvider(routes ?? FakeRouteRepository()),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  group('Golden', () {
    // No mockup: the JOIN CLUB layout (auth screens 08/09) with one button.
    goldenTest(
      'Club loop link',
      fileName: 'link_club_loop',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      pumpBeforeTest: (tester) async => tester.pumpAndSettle(),
      builder: () => _app(
        initial: '/l/$_loopId',
        links: FakeLinkRepository({_loopId: _clubLoop}),
      ),
    );
  });

  group('loop links', () {
    testWidgets('a loop the rider can see opens its preview from here', (
      tester,
    ) async {
      final routes = FakeRouteRepository();
      await _pump(
        tester,
        _app(
          initial: '/l/$_loopId',
          links: FakeLinkRepository({_loopId: _okLoop}),
          routes: routes,
        ),
      );
      expect(routes.rideLoops, [_loopId]);
      expect(find.text('PREVIEW TANAY SUNRISE LOOP'), findsOneWidget);
    });

    testWidgets('a club loop asks the rider to join the club', (tester) async {
      final routes = FakeRouteRepository();
      await _pump(
        tester,
        _app(
          initial: '/l/$_loopId',
          links: FakeLinkRepository({_loopId: _clubLoop}),
          routes: routes,
        ),
      );
      expect(find.text('CLUB LOOP'), findsOneWidget);
      expect(find.textContaining('members of Rizal Riders'), findsOneWidget);
      expect(routes.rideLoops, isEmpty);

      await tester.tap(find.text('GO TO HOME'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('private and deleted loops say so', (tester) async {
      await _pump(
        tester,
        _app(
          initial: '/l/$_loopId',
          links: FakeLinkRepository({
            _loopId: const LinkPreview(status: LinkStatus.private),
          }),
        ),
      );
      expect(find.text('PRIVATE LOOP'), findsOneWidget);

      await _pump(
        tester,
        _app(initial: '/l/gone', links: FakeLinkRepository()),
      );
      expect(find.text('LOOP NOT FOUND'), findsOneWidget);
    });

    testWidgets('without location, asks to turn it on', (tester) async {
      await _pump(
        tester,
        _app(
          initial: '/l/$_loopId',
          links: FakeLinkRepository({_loopId: _okLoop}),
          location: _location(withFix: false, allowed: false),
        ),
      );
      expect(find.text('TANAY SUNRISE LOOP'), findsOneWidget);
      expect(
        find.text('Turn on location to ride this loop from where you are.'),
        findsOneWidget,
      );
      expect(find.text('TURN ON LOCATION'), findsOneWidget);
    });

    testWidgets('offline shows TRY AGAIN, which retries', (tester) async {
      final links = FakeLinkRepository({_loopId: _okLoop})..fail = true;
      await _pump(tester, _app(initial: '/l/$_loopId', links: links));
      expect(find.text(LinkException.offline.message), findsOneWidget);

      links.fail = false;
      await tester.tap(find.text('TRY AGAIN'));
      await tester.pumpAndSettle();
      expect(find.text('PREVIEW TANAY SUNRISE LOOP'), findsOneWidget);
    });
  });

  group('post links', () {
    testWidgets('shows the post card', (tester) async {
      final feed = FakeFeedRepository(
        [],
        scoped: {
          const FeedScope.post(_postId): [
            feedPost(
              id: _postId,
              createdAt: _now.subtract(const Duration(hours: 2)),
              loopName: 'Tanay Sunrise Loop',
              caption: 'Sulit ang akyat!',
            ),
          ],
        },
      );
      await _pump(
        tester,
        _app(
          initial: '/p/$_postId',
          links: FakeLinkRepository({
            _postId: const LinkPreview(status: LinkStatus.ok),
          }),
          feed: feed,
        ),
      );
      expect(find.text('RIDE'), findsOneWidget);
      expect(find.text('Sulit ang akyat!'), findsOneWidget);
      expect(feed.scopeCalls, [const FeedScope.post(_postId)]);
    });

    testWidgets('a club post asks the rider to join', (tester) async {
      final feed = FakeFeedRepository([]);
      await _pump(
        tester,
        _app(
          initial: '/p/$_postId',
          links: FakeLinkRepository({_postId: _clubLoop}),
          feed: feed,
        ),
      );
      expect(find.text('CLUB POST'), findsOneWidget);
      expect(feed.scopeCalls, isEmpty);
    });
  });
}
