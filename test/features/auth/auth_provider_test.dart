import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('starts signed out without a session', () {
    final auth = AuthProvider(FakeAuthRepository());
    expect(auth.status, AuthStatus.signedOut);
  });

  test('restored session loads the profile', () async {
    final repo = FakeAuthRepository(
      session: fakeSession(),
      profile: fakeProfile(onboardingCompleted: false),
    );
    final auth = AuthProvider(repo);
    expect(auth.status, AuthStatus.loadingProfile);
    await settle();
    expect(auth.status, AuthStatus.signedIn);
    expect(auth.onboardingCompleted, isFalse);
  });

  test('sign in, then sign out', () async {
    final repo = FakeAuthRepository(profile: fakeProfile());
    final auth = AuthProvider(repo);
    repo.emit(AuthChangeEvent.signedIn, fakeSession());
    await settle();
    await settle();
    expect(auth.status, AuthStatus.signedIn);
    expect(auth.onboardingCompleted, isTrue);

    await auth.signOut();
    await settle();
    expect(auth.status, AuthStatus.signedOut);
    expect(auth.profile, isNull);
  });

  test('profile errors are reported and can be retried', () async {
    final repo = FakeAuthRepository(session: fakeSession())
      ..profileError = Exception('offline');
    final auth = AuthProvider(repo);
    await settle();
    expect(auth.status, AuthStatus.profileError);

    repo
      ..profileError = null
      ..profile = fakeProfile();
    await auth.reloadProfile();
    expect(auth.status, AuthStatus.signedIn);
  });

  test(
    'password recovery is set by the link and cleared by a new password',
    () async {
      final repo = FakeAuthRepository(profile: fakeProfile());
      final auth = AuthProvider(repo);
      repo.emit(AuthChangeEvent.passwordRecovery, fakeSession());
      await settle();
      expect(auth.passwordRecovery, isTrue);

      await auth.updatePassword('new-password');
      expect(auth.passwordRecovery, isFalse);
    },
  );

  test('terms accepted on Register are saved once the profile loads', () async {
    final repo = FakeAuthRepository(profile: fakeProfile());
    AuthProvider(repo).acceptTermsOnSignIn();
    repo.emit(AuthChangeEvent.signedIn, fakeSession());
    await settle();
    await settle();
    expect(repo.profileUpdates.single, contains('terms_accepted_at'));
  });
}
