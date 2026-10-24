import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/core/router.dart';
import 'package:pasyarph/core/settings/app_settings.dart';
import 'package:pasyarph/core/share.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/models/loop.dart';
import 'package:pasyarph/data/models/profile.dart';
import 'package:pasyarph/data/repositories/avatar_repository.dart';
import 'package:pasyarph/data/repositories/club_repository.dart';
import 'package:pasyarph/data/repositories/feed_repository.dart';
import 'package:pasyarph/data/repositories/loop_repository.dart';
import 'package:pasyarph/data/repositories/me_repository.dart';
import 'package:pasyarph/data/repositories/moderation_repository.dart';
import 'package:pasyarph/data/repositories/ride_history_repository.dart';
import 'package:pasyarph/data/repositories/route_repository.dart';
import 'package:pasyarph/data/repositories/social_repository.dart';
import 'package:pasyarph/features/auth/providers/auth_provider.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';
import 'package:pasyarph/features/feed/post_more.dart';
import 'package:pasyarph/features/me/providers/me_controller.dart';
import 'package:pasyarph/features/me/screens/me_screen.dart';
import 'package:pasyarph/features/me/screens/settings_screen.dart';
import 'package:pasyarph/features/onboarding/providers/onboarding_provider.dart';
import 'package:pasyarph/features/onboarding/screens/onboarding_profile_screen.dart';
import 'package:pasyarph/features/ride/providers/loop_preview_provider.dart';
import 'package:provider/provider.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_clubs.dart';
import '../../support/fake_feed.dart';
import '../../support/fake_links.dart';
import '../../support/fake_me.dart';
import '../../support/fake_moderation.dart';
import '../../support/fake_services.dart';
import '../../support/fake_social.dart';

final _now = DateTime(2026, 10, 24, 9);
const _uid = 'user-1';
const _screen = BoxConstraints.tightFor(width: 390, height: 844);

final _profile = Profile(
  id: _uid,
  createdAt: DateTime.utc(2026, 10, 18),
  fullName: 'Ana Rider',
  displayName: 'Ana Rider',
  homeArea: 'Cordon, Isabela',
  bikeType: BikeType.underbone,
  onboardingCompleted: true,
);

Loop _loop(
  String id,
  String name, {
  LoopVisibility visibility = LoopVisibility.public,
  String ownerId = 'rico',
}) => Loop(
  id: id,
  ownerId: ownerId,
  name: name,
  source: LoopSource.custom,
  sharedRoute: DemoRoutes.loop,
  distanceM: 82000,
  durationS: 9000,
  visibility: visibility,
  province: 'Rizal',
  createdAt: _now,
);

/// Everything the Me tab, Settings and Edit profile read.
class _World {
  _World({bool moving = false})
    : location = LocationProvider(
        permissions: FakeLocationPermission(),
        positions: FakePositionSource(
          last: RiderFix(point: DemoRoutes.start, speedMps: moving ? 8 : 0),
        ),
      );

  final auth = FakeAuthRepository(session: fakeSession(), profile: _profile);
  final me = FakeMeRepository(
    serverTotals: const RiderTotals(
      riddenM: 1284300,
      loopsRidden: 23,
      posts: 3,
    ),
    loops: {'saved-1': _loop('saved-1', 'Tanay Sunrise Loop')},
  );
  final loops = FakeLoopRepository();
  final moderation = FakeModerationRepository();
  final history = FakeRideHistory();
  final sharer = FakeSharer();
  final settings = AppSettings(MemorySettingsStore());
  final LocationProvider location;
  late final feed = FakeFeedRepository(
    const [],
    scoped: {
      const FeedScope.rider(_uid): [
        for (final (i, photos) in [
          ['#C2410C', '#9A3412'],
          ['#1D4ED8'],
          <String>[],
          ['#F2A27A'],
        ].indexed)
          feedPost(
            id: 'p$i',
            createdAt: _now.subtract(Duration(days: i)),
            photos: photos,
          ),
        feedPost(id: 'shared', createdAt: _now, loopOnly: true),
      ],
    },
  );

  Widget app({String initial = Routes.me, bool banner = false}) {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(
          path: Routes.me,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) =>
                MeController(me: me, feed: feed, rides: history, userId: _uid),
            child: const MeScreen(),
          ),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: Routes.editProfile,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => OnboardingProvider(
              auth: context.read<AuthProvider>(),
              avatars: FakeAvatarRepository(),
              location: FakeLocationPermission(),
            ),
            child: const OnboardingProfileScreen(editing: true),
          ),
        ),
        GoRoute(
          path: Routes.postLinkPath,
          builder: (context, state) =>
              Scaffold(body: Text('POST ${state.pathParameters['postId']}')),
        ),
        GoRoute(
          path: Routes.loopPreview,
          builder: (context, state) => const Scaffold(body: Text('PREVIEW')),
        ),
      ],
    );
    return MultiProvider(
      providers: [
        Provider<MeRepository>.value(value: me),
        Provider<ModerationRepository>.value(value: moderation),
        Provider<LoopRepository>.value(value: loops),
        Provider<RideHistoryRepository>.value(value: history),
        Provider<FeedRepository>.value(value: feed),
        Provider<ClubRepository>(create: (_) => FakeClubRepository()),
        Provider<SocialRepository>(
          create: (_) => FakeSocialRepository(userId: _uid),
        ),
        Provider<AvatarRepository>(create: (_) => FakeAvatarRepository()),
        Provider<Sharer>.value(value: sharer),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: location),
        ChangeNotifierProvider(create: (_) => AuthProvider(auth)),
        ChangeNotifierProvider(
          create: (_) => LoopPreviewProvider(FakeRouteRepository()),
        ),
        Provider<RouteRepository>(create: (_) => FakeRouteRepository()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: banner,
      ),
    );
  }
}

Future<_World> _pump(
  WidgetTester tester, {
  _World? world,
  String initial = Routes.me,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final w = world ?? _World();
  await w.location.start();
  await tester.pumpWidget(w.app(initial: initial));
  await tester.pumpAndSettle();
  return w;
}

Future<void> _settle(WidgetTester tester) async {
  // Photos are decoded off the test clock.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Golden', () {
    // No mockups: the header borrows from a rider's profile (Prompt 17),
    // the tabs from the Create sheet's segmented control.
    goldenTest(
      'Me tab, posts',
      fileName: 'me_posts',
      constraints: _screen,
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await _settle(tester);
      },
      builder: () {
        final w = _World();
        w.location.start();
        return w.app();
      },
    );
    goldenTest(
      'Settings',
      fileName: 'settings',
      constraints: _screen,
      pumpBeforeTest: (tester) async => tester.pumpAndSettle(),
      builder: () {
        final w = _World();
        w.location.start();
        return w.app(initial: Routes.settings);
      },
    );
  });

  testWidgets('header: name, home, bike and totals', (tester) async {
    await _pump(tester);
    expect(find.text('Ana Rider'), findsOneWidget);
    expect(find.text('Cordon, Isabela · Underbone'), findsOneWidget);
    expect(find.text('1,284'), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('totals update right after a ride', (tester) async {
    final w = await _pump(tester);
    await w.history.save(
      RideSummary(
        id: '11111111-1111-1111-1111-111111111111',
        startedAt: _now.subtract(const Duration(hours: 3)),
        endedAt: _now,
        riddenM: 85700,
        loopM: 82000,
        reachedStop: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1,370'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
  });

  testWidgets('Posts: a grid of posts; tapping one opens it', (tester) async {
    await _pump(tester);
    await _settle(tester);
    expect(find.text('YOUR POSTS'), findsOneWidget);
    // Four posts; the loop shared without a post isn't in the grid.
    expect(
      find.bySemanticsLabel(RegExp(r'^Sunday Falls Loop, ')),
      findsNWidgets(4),
    );
    expect(
      find.bySemanticsLabel('Sunday Falls Loop, 2 photos'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Sunday Falls Loop, no photos'),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('Sunday Falls Loop, 2 photos'));
    await tester.pumpAndSettle();
    expect(find.text('POST p0'), findsOneWidget);
  });

  group('My loops', () {
    Future<_World> openLoops(WidgetTester tester) async {
      final w = _World();
      await w.loops.create(
        'mine-1',
        NewLoop(
          name: 'Sunday Falls Loop',
          source: LoopSource.custom,
          route: DemoRoutes.loop,
          distanceM: 96000,
          durationS: 11400,
        ),
      );
      await _pump(tester, world: w);
      await tester.tap(find.text('My loops'));
      await tester.pumpAndSettle();
      return w;
    }

    testWidgets('shows who can see each loop', (tester) async {
      await openLoops(tester);
      expect(find.text('Sunday Falls Loop'), findsOneWidget);
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Made by you'), findsOneWidget);
      expect(find.text('YOUR CLUBS'), findsOneWidget);
    });

    testWidgets('⋯ → edit renames it and makes it private', (tester) async {
      final w = await openLoops(tester);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit name and who sees it'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Sunrise Falls');
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();
      expect(find.text('Only you can see this loop.'), findsOneWidget);
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      expect(w.loops.saved['mine-1']!.name, 'Sunrise Falls');
      expect(w.loops.saved['mine-1']!.visibility, LoopVisibility.private);
      expect(find.text('Sunrise Falls'), findsOneWidget);
      expect(find.text('Loop updated.'), findsOneWidget);
    });

    testWidgets('⋯ → share sends the link', (tester) async {
      final w = await openLoops(tester);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share link'));
      await tester.pumpAndSettle();
      expect(
        w.sharer.shared.single,
        contains('https://pasyar.pages.dev/l/mine-1'),
      );
    });

    testWidgets('⋯ → delete asks first', (tester) async {
      final w = await openLoops(tester);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete loop'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this loop?'), findsOneWidget);
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();
      expect(w.loops.saved, isEmpty);
      expect(find.text('Sunday Falls Loop'), findsNothing);
    });
  });

  testWidgets('Saved: saved loops, and removing one', (tester) async {
    final w = _World();
    await w.me.saveLoop('saved-1');
    await _pump(tester, world: w);
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Tanay Sunrise Loop'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from saved'));
    await tester.pumpAndSettle();
    expect(w.me.saved, isEmpty);
    expect(find.text('Tanay Sunrise Loop'), findsNothing);
  });

  testWidgets("a post's ⋯ saves its loop to Saved", (tester) async {
    final w = _World();
    await _pump(tester, world: w);
    final post = feedPost(id: 'x', createdAt: _now);
    final context = tester.element(find.byType(MeScreen));
    // ignore: unawaited_futures
    showPostMore(context, post, onShare: () {});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save loop to ride later'));
    await tester.pumpAndSettle();
    expect(w.me.saved, [post.loop.id]);
    expect(find.text('Saved. Find it under Me → Saved.'), findsOneWidget);

    // ignore: unawaited_futures
    showPostMore(context, post, onShare: () {});
    await tester.pumpAndSettle();
    expect(find.text('Remove from saved loops'), findsOneWidget);
  });

  testWidgets("a post's ⋯ blocks just that post, with UNDO", (tester) async {
    final w = _World();
    await _pump(tester, world: w);
    var reloads = 0;
    final post = feedPost(id: 'x', createdAt: _now);
    final context = tester.element(find.byType(MeScreen));
    // ignore: unawaited_futures
    showPostMore(context, post, onShare: () {}, onBlocked: () => reloads++);
    await tester.pumpAndSettle();
    expect(find.text('Block Rico Navarro'), findsOneWidget);
    await tester.tap(find.text('Block this post'));
    await tester.pumpAndSettle();
    expect(w.moderation.blockedItems, [(BlockedItem.post, 'x')]);
    expect(w.moderation.blockedIds, isEmpty, reason: 'the rider stays');
    expect(reloads, 1);
    expect(find.text("Post blocked. You won't see it again."), findsOneWidget);

    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect(w.moderation.blockedItems, isEmpty);
    expect(reloads, 2);
  });

  testWidgets("a shared loop's ⋯ blocks the loop", (tester) async {
    final w = _World();
    await _pump(tester, world: w);
    final post = feedPost(id: 'l', createdAt: _now, loopOnly: true);
    final context = tester.element(find.byType(MeScreen));
    // ignore: unawaited_futures
    showPostMore(context, post, onShare: () {});
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block this loop'));
    await tester.pumpAndSettle();
    expect(w.moderation.blockedItems, [(BlockedItem.loop, post.loop.id)]);
  });

  group('Settings', () {
    testWidgets('voice prompts toggle, km and the 800 m privacy trim', (
      tester,
    ) async {
      final w = await _pump(tester, initial: Routes.settings);
      expect(find.text('Kilometers'), findsOneWidget);
      expect(find.text('Home privacy: 800 m hidden'), findsOneWidget);
      expect(w.settings.voicePrompts, isTrue);
      await tester.tap(find.bySemanticsLabel('Voice prompts'));
      await tester.pumpAndSettle();
      expect(w.settings.voicePrompts, isFalse);
    });

    testWidgets('delete account: type DELETE, then everything goes', (
      tester,
    ) async {
      final w = await _pump(tester, initial: Routes.settings);
      await tester.scrollUntilVisible(
        find.text('DELETE ACCOUNT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();

      TextButton deleteButton() =>
          tester.widget<TextButton>(find.widgetWithText(TextButton, 'DELETE'));
      expect(deleteButton().onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'delete');
      await tester.pumpAndSettle();
      expect(deleteButton().onPressed, isNotNull);

      await tester.tap(find.widgetWithText(TextButton, 'DELETE'));
      await tester.pumpAndSettle();
      expect(w.me.deleted, isTrue);
      expect(w.auth.calls, contains('signOut'));
    });

    testWidgets('a spinner shows while deleting; it can\'t be closed', (
      tester,
    ) async {
      final w = _World();
      w.me.deleteGate = Completer<void>();
      await _pump(tester, world: w, initial: Routes.settings);
      await tester.scrollUntilVisible(
        find.text('DELETE ACCOUNT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'DELETE'));
      await tester.pump();

      expect(find.text('Deleting your account and photos…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('CANCEL'), findsNothing);
      // Back and tapping outside don't close it.
      await tester.binding.handlePopRoute();
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(find.text('Deleting your account and photos…'), findsOneWidget);
      expect(w.auth.calls, isNot(contains('signOut')));

      w.me.deleteGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Deleting your account and photos…'), findsNothing);
      expect(w.auth.calls, contains('signOut'));
    });

    testWidgets('delete account fails: the account stays', (tester) async {
      final w = _World();
      w.me.fail = true;
      await _pump(tester, world: w, initial: Routes.settings);
      await tester.scrollUntilVisible(
        find.text('DELETE ACCOUNT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'DELETE'));
      await tester.pumpAndSettle();
      expect(find.text(MeException.deleteFailed.message), findsOneWidget);
      expect(w.auth.calls, isNot(contains('signOut')));
    });

    testWidgets('no typing DELETE while moving', (tester) async {
      await _pump(
        tester,
        world: _World(moving: true),
        initial: Routes.settings,
      );
      await tester.scrollUntilVisible(
        find.text('DELETE ACCOUNT'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DELETE ACCOUNT'));
      await tester.pumpAndSettle();
      expect(find.text('Stop riding first.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  group('Edit profile', () {
    testWidgets('saves the changes and goes back', (tester) async {
      final w = await _pump(tester);
      await tester.tap(find.text('EDIT PROFILE'));
      await tester.pumpAndSettle();
      expect(find.text('EDIT PROFILE'), findsOneWidget);
      expect(find.text('SAVE'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'Ana R.');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(w.auth.profileUpdates.last['display_name'], 'Ana R.');
      expect(find.byType(MeScreen), findsOneWidget);
      expect(find.text('Profile saved.'), findsOneWidget);
    });

    testWidgets('locked while moving', (tester) async {
      await _pump(
        tester,
        world: _World(moving: true),
        initial: Routes.editProfile,
      );
      expect(find.text('Stop riding to edit your profile.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse,
      );
    });
  });
}
