import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/app.dart';
import 'package:pasyarph/core/location/location_permission.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/features/ride/providers/loop_preview_provider.dart';
import 'package:pasyarph/features/ride/providers/ride_session_provider.dart';
import 'package:pasyarph/features/ride/screens/loop_preview_screen.dart';
import 'package:pasyarph/features/ride/screens/ride_session_screen.dart';
import 'package:pasyarph/core/widgets/bottom_tabs.dart';
import 'package:pasyarph/data/models/post.dart';
import 'package:pasyarph/data/repositories/avatar_repository.dart';
import 'package:pasyarph/data/models/profile.dart';
import 'package:pasyarph/data/repositories/club_repository.dart';
import 'package:pasyarph/data/repositories/feed_repository.dart';
import 'package:pasyarph/data/repositories/post_repository.dart';
import 'package:pasyarph/data/repositories/ride_history_repository.dart';
import 'package:pasyarph/data/repositories/social_repository.dart';
import 'package:pasyarph/features/post/post_draft.dart';
import 'package:pasyarph/features/auth/providers/auth_provider.dart';
import 'package:pasyarph/features/auth/screens/login_screen.dart';
import 'package:pasyarph/features/auth/screens/welcome_screen.dart';
import 'package:pasyarph/data/repositories/loop_repository.dart';
import 'package:pasyarph/data/repositories/route_repository.dart';
import 'package:pasyarph/features/create/screens/create_loop_screen.dart';
import 'package:pasyarph/features/feed/providers/feed_provider.dart';
import 'package:pasyarph/features/clubs/club_rules.dart';
import 'package:pasyarph/features/clubs/screens/club_screen.dart';
import 'package:pasyarph/features/clubs/screens/create_club_screen.dart';
import 'package:pasyarph/features/clubs/screens/join_club_screen.dart';
import 'package:pasyarph/features/feed/screens/feed_screen.dart';
import 'package:pasyarph/features/me/screens/me_screen.dart';
import 'package:pasyarph/features/riders/screens/rider_profile_screen.dart';
import 'package:pasyarph/features/onboarding/screens/onboarding_location_screen.dart';
import 'package:pasyarph/features/onboarding/screens/onboarding_profile_screen.dart';
import 'package:pasyarph/features/ride/screens/ride_screen.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_clubs.dart';
import 'support/fake_feed.dart';
import 'support/fake_post.dart';
import 'support/fake_services.dart';
import 'support/fake_social.dart';

/// Links the app tried to open (Google Maps).
final openedUrls = <Uri>[];

Future<FakeAuthRepository> pumpApp(
  WidgetTester tester,
  FakeAuthRepository repo, {
  FakeLocationPermission? location,
  List<FeedPost> feedPosts = const [],
  FakeRouteRepository? routes,
  FakeClubRepository? clubs,
  FakeSocialRepository? social,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final history = FakeRideHistory();
  final routeRepo = routes ?? FakeRouteRepository();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<RouteRepository>.value(value: routeRepo),
        Provider<LoopRepository>(create: (_) => FakeLoopRepository()),
        Provider<ClubRepository>(create: (_) => clubs ?? FakeClubRepository()),
        Provider<RideHistoryRepository>.value(value: history),
        Provider<PostRepository>(create: (_) => FakePosts()),
        Provider<FeedRepository>(create: (_) => FakeFeedRepository(feedPosts)),
        Provider<SocialRepository>(
          create: (_) => social ?? FakeSocialRepository(),
        ),
        Provider<PostDraftStore>(
          create: (_) => MemoryDrafts(Directory.systemTemp),
        ),
        Provider<AvatarRepository>(create: (_) => FakeAvatarRepository()),
        Provider<LocationPermissionService>(
          create: (_) => location ?? FakeLocationPermission(),
        ),
        ChangeNotifierProvider(
          create: (context) => LocationProvider(
            permissions: context.read<LocationPermissionService>(),
            positions: FakePositionSource(
              last: const RiderFix(point: LatLng(16.672, 121.457)),
            ),
          ),
        ),
        ChangeNotifierProvider(create: (_) => LoopPreviewProvider(routeRepo)),
        ChangeNotifierProvider(
          create: (context) => RideSessionProvider(
            location: context.read<LocationProvider>(),
            notifier: FakeRideNotifier(),
            history: history,
            openUrl: (url) async {
              openedUrls.add(url);
              return true;
            },
            tickEvery: null,
          ),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider(repo)),
        ChangeNotifierProvider(
          create: (context) => FeedProvider(
            feed: context.read<FeedRepository>(),
            social: context.read<SocialRepository>(),
            location: context.read<LocationProvider>(),
          ),
        ),
      ],
      child: const PasyarApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('signed out: Welcome, then Log in', (tester) async {
    await pumpApp(tester, FakeAuthRepository());
    expect(find.byType(WelcomeScreen), findsOneWidget);

    await tester.tap(find.text('I ALREADY HAVE AN ACCOUNT'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('log in validates the form before calling Supabase', (
    tester,
  ) async {
    final repo = await pumpApp(tester, FakeAuthRepository());
    await tester.tap(find.text('I ALREADY HAVE AN ACCOUNT'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('LOG IN'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email.'), findsOneWidget);
    expect(repo.calls, isNot(contains(startsWith('signInWithPassword'))));

    await tester.enterText(find.byType(TextField).first, 'ana@test.ph');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.tap(find.text('LOG IN'));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('signInWithPassword:ana@test.ph'));
  });

  testWidgets('new account: onboarding step 1 → step 2 → Ride', (tester) async {
    final location = FakeLocationPermission(LocationAccess.denied);
    final repo = await pumpApp(
      tester,
      FakeAuthRepository(
        session: fakeSession(),
        profile: fakeProfile(onboardingCompleted: false),
      ),
      location: location,
    );
    expect(find.byType(OnboardingProfileScreen), findsOneWidget);
    // Rider name is prefilled with the first name ("Ana Rider" → "Ana").
    expect(find.widgetWithText(TextField, 'Ana'), findsOneWidget);

    await tester.tap(find.text('UNDERBONE'));
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingLocationScreen), findsOneWidget);
    expect(repo.profileUpdates.first, {
      'display_name': 'Ana',
      'bike_type': 'underbone',
      'home_area': null,
      'avatar_url': null,
    });

    // Back keeps the draft.
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingProfileScreen), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    // Denied permission still finishes onboarding.
    await tester.tap(find.text('ALLOW LOCATION'));
    await tester.pumpAndSettle();
    expect(location.requests, 1);
    expect(find.byType(RideScreen), findsOneWidget);
  });

  testWidgets('"Not now" finishes without asking for location', (tester) async {
    final location = FakeLocationPermission();
    await pumpApp(
      tester,
      FakeAuthRepository(
        session: fakeSession(),
        profile: fakeProfile(onboardingCompleted: false),
      ),
      location: location,
    );
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(location.requests, 0);
    expect(find.byType(RideScreen), findsOneWidget);
  });

  testWidgets('Generate opens the preview; Shuffle; Back returns to Ride', (
    tester,
  ) async {
    await pumpApp(
      tester,
      FakeAuthRepository(session: fakeSession(), profile: fakeProfile()),
    );
    await tester.tap(find.text('GENERATE LOOP'));
    await tester.pumpAndSettle();
    expect(find.byType(LoopPreviewScreen), findsOneWidget);
    expect(find.text('HALF-DAY LOOP'), findsOneWidget);
    expect(find.byType(PasyarBottomTabs), findsNothing);

    await tester.tap(find.text('SHUFFLE'));
    await tester.pumpAndSettle();
    expect(find.byType(LoopPreviewScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(RideScreen), findsOneWidget);
  });

  testWidgets('START RIDE opens Google Maps and the ride; END RIDE saves', (
    tester,
  ) async {
    openedUrls.clear();
    await pumpApp(
      tester,
      FakeAuthRepository(session: fakeSession(), profile: fakeProfile()),
    );
    await tester.tap(find.text('GENERATE LOOP'));
    await tester.pumpAndSettle();
    // start() runs a chain of async steps (notification permission,
    // background tracking, opening Maps); let it finish on the real clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('START RIDE'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.byType(RideSessionScreen), findsOneWidget);
    expect(find.text('RIDE IN PROGRESS'), findsOneWidget);
    expect(openedUrls.single.host, 'www.google.com');

    await tester.tap(find.text('GOOGLE MAPS'));
    await tester.pumpAndSettle();
    expect(openedUrls, hasLength(2));

    await tester.tap(find.text('END RIDE'));
    await tester.pumpAndSettle();
    expect(find.text('END THIS RIDE?'), findsOneWidget);
    await tester.tap(find.text('END RIDE').last);
    await tester.pumpAndSettle();
    expect(find.text('LOOP DONE'), findsOneWidget);

    await tester.tap(find.text('FINISH LOOP'));
    await tester.pumpAndSettle();
    expect(find.byType(RideScreen), findsOneWidget);
  });

  testWidgets('RIDE IT on a post previews that loop from here', (tester) async {
    final routes = FakeRouteRepository();
    await pumpApp(
      tester,
      FakeAuthRepository(session: fakeSession(), profile: fakeProfile()),
      feedPosts: mockupPosts(DateTime.now()),
      routes: routes,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(PasyarBottomTabs),
        matching: find.text('Feed'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('RIDE IT').first);
    await tester.pumpAndSettle();

    expect(routes.rideLoops, ['loop-p1']);
    expect(find.byType(LoopPreviewScreen), findsOneWidget);
    expect(find.text('SUNDAY FALLS LOOP'), findsOneWidget);
    expect(find.text('Includes 3.0 km to the loop and back.'), findsOneWidget);
    expect(find.text('SHUFFLE'), findsNothing);
    expect(find.text('START RIDE'), findsOneWidget);
  });

  testWidgets('signed in: tabs switch, and Me logs out', (tester) async {
    await pumpApp(
      tester,
      FakeAuthRepository(session: fakeSession(), profile: fakeProfile()),
    );
    expect(find.byType(RideScreen), findsOneWidget);

    Future<void> tapTab(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(PasyarBottomTabs),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    final tabs = {'Feed': FeedScreen, 'Me': MeScreen, 'Ride': RideScreen};
    for (final MapEntry(key: label, value: screen) in tabs.entries) {
      await tapTab(label);
      expect(find.byType(screen), findsOneWidget, reason: label);
    }

    // Create opens full screen over the tabs; Back returns to the tab.
    await tapTab('Create');
    expect(find.byType(CreateLoopScreen), findsOneWidget);
    expect(find.byType(PasyarBottomTabs), findsNothing);
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(RideScreen), findsOneWidget);

    await tester.tap(find.text('Me').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  group('clubs and follows (Prompt 17)', () {
    final copied = <String>[];
    setUp(() {
      copied.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          });
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Future<void> openMe(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(PasyarBottomTabs),
          matching: find.text('Me'),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tapScrolled(WidgetTester tester, Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    testWidgets('make a club, copy its invite link, find it under Me', (
      tester,
    ) async {
      final clubs = FakeClubRepository();
      await pumpApp(
        tester,
        FakeAuthRepository(session: fakeSession(), profile: fakeProfile()),
        clubs: clubs,
      );
      await openMe(tester);
      expect(find.text('YOUR CLUBS'), findsOneWidget);
      await tapScrolled(tester, find.text('CREATE A CLUB'));
      expect(find.byType(CreateClubScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Cordon Riders');
      await tester.pump();
      await tester.tap(find.text('CREATE CLUB'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubScreen), findsOneWidget);
      expect(find.text('Cordon Riders'), findsOneWidget);
      expect(find.text('Owner · 1 member'), findsOneWidget);

      await tester.tap(find.text('INVITE RIDERS'));
      await tester.pumpAndSettle();
      expect(copied.single, startsWith('https://pasyar.app/join/'));
      expect(parseInviteCode(copied.single), clubs.codes.values.single);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(MeScreen), findsOneWidget);
      expect(find.text('Owner · 1 member'), findsOneWidget);
    });

    testWidgets('join a club with a pasted link, then leave it', (
      tester,
    ) async {
      final clubs = FakeClubRepository()
        ..add(
          'isa',
          'Isabela Riders',
          ownerId: 'rico',
          memberIds: ['ana'],
          code: '0123456789abcdef',
        );
      await pumpApp(
        tester,
        FakeAuthRepository(session: fakeSession(), profile: fakeProfile()),
        clubs: clubs,
      );
      await openMe(tester);
      await tapScrolled(tester, find.text('JOIN WITH A LINK'));

      await tester.enterText(
        find.byType(TextField).last,
        'https://pasyar.app/join/0123456789abcdef',
      );
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      expect(find.byType(JoinClubScreen), findsOneWidget);
      expect(find.text('Isabela Riders'), findsOneWidget);
      expect(find.text('2 members'), findsOneWidget);

      await tester.tap(find.text('JOIN CLUB'));
      await tester.pumpAndSettle();
      expect(find.byType(ClubScreen), findsOneWidget);
      expect(find.text('Member · 3 members'), findsOneWidget);
      expect(find.text('MEMBERS'), findsOneWidget);

      await tester.tap(find.text('LEAVE CLUB'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(find.byType(MeScreen), findsOneWidget);
      expect(find.text('Isabela Riders'), findsNothing);
    });

    testWidgets("a post's author opens their profile; FOLLOW", (tester) async {
      final now = DateTime.now();
      final social = FakeSocialRepository(
        riders: {
          'author-p1': const RiderProfile(
            id: 'author-p1',
            displayName: 'Rico Navarro',
            homeArea: 'Cordon, Isabela',
            followerCount: 2,
          ),
        },
      );
      await pumpApp(
        tester,
        FakeAuthRepository(session: fakeSession(), profile: fakeProfile()),
        feedPosts: [
          feedPost(id: 'p1', createdAt: now, photos: const ['#A8B9A0']),
        ],
        social: social,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(PasyarBottomTabs),
          matching: find.text('Feed'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining('Rico Navarro rode', findRichText: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RiderProfileScreen), findsOneWidget);
      expect(find.text('Cordon, Isabela'), findsOneWidget);

      await tester.tap(find.text('FOLLOW'));
      await tester.pumpAndSettle();
      expect(find.text('FOLLOWING'), findsOneWidget);
      expect(social.follows, {'author-p1'});
      expect(
        find.textContaining('3 followers', findRichText: true),
        findsOneWidget,
      );
    });
  });
}
