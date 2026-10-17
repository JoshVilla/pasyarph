import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/json.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/auth_repository.dart';

enum AuthStatus {
  signedOut,

  /// Signed in, profile still loading.
  loadingProfile,

  /// Signed in, but the profile couldn't be loaded.
  profileError,

  /// Signed in with a loaded profile.
  signedIn,
}

/// Session, user and profile for the whole app. The router listens to this
/// to decide where to send the user.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo) {
    _session = _repo.currentSession;
    _sub = _repo.events.listen(_onEvent);
    if (_session != null) unawaited(reloadProfile());
  }

  final AuthRepository _repo;
  late final StreamSubscription<AuthEvent> _sub;

  Session? _session;
  Profile? _profile;
  Object? _profileError;
  bool _loadingProfile = false;
  bool _passwordRecovery = false;

  Session? get session => _session;
  User? get user => _session?.user;
  Profile? get profile => _profile;
  Object? get profileError => _profileError;

  /// True after opening a password-reset link, until a new password is set.
  bool get passwordRecovery => _passwordRecovery;

  bool get onboardingCompleted => _profile?.onboardingCompleted ?? false;

  AuthStatus get status {
    if (_session == null) return AuthStatus.signedOut;
    if (_profile != null) return AuthStatus.signedIn;
    if (_profileError != null && !_loadingProfile) {
      return AuthStatus.profileError;
    }
    return AuthStatus.loadingProfile;
  }

  void _onEvent(AuthEvent e) {
    switch (e.event) {
      case AuthChangeEvent.signedOut:
        _session = null;
        _profile = null;
        _profileError = null;
        _passwordRecovery = false;
        notifyListeners();
      case AuthChangeEvent.passwordRecovery:
        _passwordRecovery = true;
        _setSession(e.session);
      default:
        _setSession(e.session);
    }
  }

  void _setSession(Session? session) {
    final userChanged = session?.user.id != _session?.user.id;
    _session = session;
    if (session == null) {
      _profile = null;
    } else if (userChanged || _profile == null) {
      _profile = null;
      unawaited(reloadProfile());
    }
    notifyListeners();
  }

  Future<void> reloadProfile() async {
    final userId = user?.id;
    if (userId == null) return;
    _loadingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      var profile = await _repo.fetchProfile(userId);
      if (_acceptTermsPending && profile != null) {
        _acceptTermsPending = false;
        if (profile.termsAcceptedAt == null) {
          await _repo.updateProfile(userId, {
            'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
          });
          profile = await _repo.fetchProfile(userId);
        }
      }
      if (user?.id != userId) return;
      _profile = profile;
      if (profile == null) _profileError = StateError('Profile not found');
    } catch (e) {
      if (user?.id == userId) _profileError = e;
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(Json fields) async {
    final userId = user?.id;
    if (userId == null) return;
    await _repo.updateProfile(userId, fields);
    await reloadProfile();
  }

  Future<void> signInWithPassword(String email, String password) =>
      _repo.signInWithPassword(email: email, password: password);

  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) => _repo.signUp(fullName: fullName, email: email, password: password);

  Future<void> resendSignUpEmail(String email) =>
      _repo.resendSignUpEmail(email);

  Future<void> signInWithGoogle() => _repo.signInWithGoogle();
  Future<void> signInWithApple() => _repo.signInWithApple();

  /// Call before a social sign-in from Register when the terms box is
  /// ticked. Saved once the profile loads, because on Android the session
  /// arrives later through the deep link.
  void acceptTermsOnSignIn() => _acceptTermsPending = true;
  bool _acceptTermsPending = false;

  Future<void> sendPasswordReset(String email) =>
      _repo.sendPasswordReset(email);

  Future<void> updatePassword(String password) async {
    await _repo.updatePassword(password);
    _passwordRecovery = false;
    notifyListeners();
  }

  Future<void> signOut() => _repo.signOut();

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
