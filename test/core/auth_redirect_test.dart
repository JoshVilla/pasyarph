import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/core/auth_redirect.dart';
import 'package:pasyarph/features/auth/providers/auth_provider.dart';

String? go(
  String location, {
  AuthStatus status = AuthStatus.signedIn,
  bool onboarded = true,
  bool recovery = false,
}) => authRedirect(
  status: status,
  onboardingCompleted: onboarded,
  passwordRecovery: recovery,
  location: location,
  home: '/ride',
  alwaysAllowed: const {'/dev/widgets'},
);

void main() {
  group('signed out', () {
    const out = AuthStatus.signedOut;

    test('app screens go to Welcome', () {
      expect(go('/ride', status: out), AuthRoutes.welcome);
      expect(go('/onboarding/profile', status: out), AuthRoutes.welcome);
      expect(go('/reset-password', status: out), AuthRoutes.welcome);
    });

    test('auth screens are allowed', () {
      for (final route in AuthRoutes.signedOutOnly) {
        expect(go(route, status: out), isNull, reason: route);
      }
    });
  });

  test('profile loading or failed shows the splash', () {
    expect(go('/ride', status: AuthStatus.loadingProfile), AuthRoutes.splash);
    expect(go('/login', status: AuthStatus.profileError), AuthRoutes.splash);
    expect(go('/splash', status: AuthStatus.loadingProfile), isNull);
  });

  test('onboarding not done goes to step 1, and stays in onboarding', () {
    expect(go('/ride', onboarded: false), AuthRoutes.onboardingProfile);
    expect(go('/login', onboarded: false), AuthRoutes.onboardingProfile);
    expect(go('/onboarding/location', onboarded: false), isNull);
  });

  test('signed in and onboarded leaves auth screens for home', () {
    expect(go('/welcome'), '/ride');
    expect(go('/login'), '/ride');
    expect(go('/splash'), '/ride');
    expect(go('/onboarding/profile'), '/ride');
    expect(go('/feed'), isNull);
  });

  test('a password reset link always goes to Set new password', () {
    expect(go('/ride', recovery: true), AuthRoutes.resetPassword);
    expect(
      go('/splash', recovery: true, status: AuthStatus.loadingProfile),
      AuthRoutes.resetPassword,
    );
    expect(go('/reset-password', recovery: true), isNull);
  });

  test('dev widgets are always reachable when registered', () {
    expect(go('/dev/widgets', status: AuthStatus.signedOut), isNull);
  });
}
