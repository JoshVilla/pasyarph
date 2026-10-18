import 'package:flutter/material.dart';
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
import 'package:pasyarph/data/repositories/avatar_repository.dart';
import 'package:pasyarph/features/auth/providers/auth_provider.dart';
import 'package:pasyarph/features/auth/screens/login_screen.dart';
import 'package:pasyarph/features/auth/screens/welcome_screen.dart';
import 'package:pasyarph/features/create/screens/create_screen.dart';
import 'package:pasyarph/features/feed/screens/feed_screen.dart';
import 'package:pasyarph/features/me/screens/me_screen.dart';
import 'package:pasyarph/features/onboarding/screens/onboarding_location_screen.dart';
import 'package:pasyarph/features/onboarding/screens/onboarding_profile_screen.dart';
import 'package:pasyarph/features/ride/screens/ride_screen.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_services.dart';

/// Links the app tried to open (Google Maps).
final openedUrls = <Uri>[];

Future<FakeAuthRepository> pumpApp(
  WidgetTester tester,
  FakeAuthRepository repo, {
  FakeLocationPermission? location,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
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
        ChangeNotifierProvider(
          create: (_) => LoopPreviewProvider(FakeRouteRepository()),
        ),
        ChangeNotifierProvider(
          create: (context) => RideSessionProvider(
            location: context.read<LocationProvider>(),
            notifier: FakeRideNotifier(),
            history: FakeRideHistory(),
            openUrl: (url) async {
              openedUrls.add(url);
              return true;
            },
            tickEvery: null,
          ),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider(repo)),
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

  testWidgets('signed in: tabs switch, and Me logs out', (tester) async {
    await pumpApp(
      tester,
      FakeAuthRepository(session: fakeSession(), profile: fakeProfile()),
    );
    expect(find.byType(RideScreen), findsOneWidget);

    final tabs = {
      'Feed': FeedScreen,
      'Create': CreateScreen,
      'Me': MeScreen,
      'Ride': RideScreen,
    };
    for (final MapEntry(key: label, value: screen) in tabs.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(PasyarBottomTabs),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget, reason: label);
    }

    await tester.tap(find.text('Me').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOG OUT'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
