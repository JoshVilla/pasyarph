import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/app.dart';
import 'package:pasyarph/core/widgets/bottom_tabs.dart';
import 'package:pasyarph/features/auth/providers/auth_provider.dart';
import 'package:pasyarph/features/auth/screens/login_screen.dart';
import 'package:pasyarph/features/auth/screens/welcome_screen.dart';
import 'package:pasyarph/features/create/screens/create_screen.dart';
import 'package:pasyarph/features/feed/screens/feed_screen.dart';
import 'package:pasyarph/features/me/screens/me_screen.dart';
import 'package:pasyarph/features/onboarding/screens/onboarding_placeholder_screen.dart';
import 'package:pasyarph/features/ride/screens/ride_screen.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth_repository.dart';

Future<FakeAuthRepository> pumpApp(
  WidgetTester tester,
  FakeAuthRepository repo,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(repo),
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

  testWidgets('new account goes to onboarding', (tester) async {
    await pumpApp(
      tester,
      FakeAuthRepository(
        session: fakeSession(),
        profile: fakeProfile(onboardingCompleted: false),
      ),
    );
    expect(find.byType(OnboardingPlaceholderScreen), findsOneWidget);

    await tester.tap(find.text('CONTINUE'));
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
