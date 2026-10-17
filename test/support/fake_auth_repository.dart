import 'dart:async';

import 'package:pasyarph/data/models/json.dart';
import 'package:pasyarph/data/models/profile.dart';
import 'package:pasyarph/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Session fakeSession({String userId = 'user-1', String email = 'a@test.ph'}) =>
    Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: User(
        id: userId,
        email: email,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-10-18T00:00:00Z',
      ),
    );

Profile fakeProfile({
  String id = 'user-1',
  bool onboardingCompleted = true,
  String? fullName = 'Ana Rider',
}) => Profile(
  id: id,
  fullName: fullName,
  onboardingCompleted: onboardingCompleted,
  createdAt: DateTime.utc(2026, 10, 18),
);

/// In-memory [AuthRepository] for widget and provider tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({Session? session, this.profile}) : _session = session;

  final _events = StreamController<AuthEvent>.broadcast();
  Session? _session;
  Profile? profile;
  Object? profileError;
  final calls = <String>[];
  final profileUpdates = <Json>[];

  void emit(AuthChangeEvent event, Session? session) {
    _session = session;
    _events.add((event: event, session: session));
  }

  @override
  Session? get currentSession => _session;

  @override
  Stream<AuthEvent> get events => _events.stream;

  @override
  Future<Profile?> fetchProfile(String userId) async {
    calls.add('fetchProfile');
    if (profileError != null) throw profileError!;
    return profile;
  }

  @override
  Future<void> updateProfile(String userId, Json fields) async {
    profileUpdates.add(fields);
    final p = profile;
    if (p != null && fields['onboarding_completed'] == true) {
      profile = fakeProfile(id: p.id, fullName: p.fullName);
    }
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async => calls.add('signInWithPassword:$email');

  @override
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    calls.add('signUp:$email');
    return SignUpResult.needsEmailConfirmation;
  }

  @override
  Future<void> resendSignUpEmail(String email) async => calls.add('resend');

  @override
  Future<void> signInWithGoogle() async => calls.add('google');

  @override
  Future<void> signInWithApple() async => calls.add('apple');

  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset');

  @override
  Future<void> updatePassword(String password) async =>
      calls.add('updatePassword');

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    emit(AuthChangeEvent.signedOut, null);
  }
}
