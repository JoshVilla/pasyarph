import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/env.dart';
import '../../features/auth/auth_errors.dart';
import '../models/json.dart';
import '../models/profile.dart';

typedef AuthEvent = ({AuthChangeEvent event, Session? session});

/// Result of an email sign-up.
enum SignUpResult {
  /// Signed in right away (email confirmation is off).
  signedIn,

  /// Account created; the user must tap the link in their email first.
  needsEmailConfirmation,
}

/// Everything the app needs from Supabase Auth and the profiles table.
abstract interface class AuthRepository {
  Session? get currentSession;
  Stream<AuthEvent> get events;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  });

  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  });

  Future<void> resendSignUpEmail(String email);
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String password);
  Future<void> signOut();

  Future<Profile?> fetchProfile(String userId);
  Future<void> updateProfile(String userId, Json fields);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  bool _googleReady = false;

  GoTrueClient get _auth => _client.auth;

  @override
  Session? get currentSession => _auth.currentSession;

  @override
  Stream<AuthEvent> get events =>
      _auth.onAuthStateChange.map((s) => (event: s.event, session: s.session));

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) => _auth.signInWithPassword(email: email.trim(), password: password);

  @override
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final res = await _auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: Env.authRedirectUrl,
      // Read by the sign-up trigger (supabase/migrations/..._profiles.sql).
      data: {'full_name': fullName.trim(), 'terms_accepted': true},
    );
    return res.session == null
        ? SignUpResult.needsEmailConfirmation
        : SignUpResult.signedIn;
  }

  @override
  Future<void> resendSignUpEmail(String email) => _auth.resend(
    type: OtpType.signup,
    email: email.trim(),
    emailRedirectTo: Env.authRedirectUrl,
  );

  @override
  Future<void> signInWithGoogle() async {
    if (Env.googleWebClientId.isEmpty) {
      throw const SignInNotConfigured('Google');
    }
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(
        serverClientId: Env.googleWebClientId,
        clientId: Platform.isIOS && Env.googleIosClientId.isNotEmpty
            ? Env.googleIosClientId
            : null,
      );
      _googleReady = true;
    }

    final GoogleSignInAccount account;
    try {
      account = await google.authenticate(scopeHint: const ['email']);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInCancelled();
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google returned no ID token');
    }

    const scopes = ['email', 'profile'];
    final authorization =
        await account.authorizationClient.authorizationForScopes(scopes) ??
        await account.authorizationClient.authorizeScopes(scopes);

    await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization.accessToken,
    );
  }

  @override
  Future<void> signInWithApple() async {
    if (!Platform.isIOS) {
      // Android: Apple's web sign-in in the browser, then back to the app
      // through the auth-callback deep link. The session arrives on [events].
      await _auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: Env.authRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return;
    }

    // iOS: native sheet, then exchange the ID token with a hashed nonce.
    final rawNonce = _randomNonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const SignInCancelled();
      }
      rethrow;
    }

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple returned no ID token');
    }

    final res = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    // Apple shares the name only on the very first sign-in. Save it now.
    final name = [
      credential.givenName,
      credential.familyName,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
    final user = res.user;
    if (name.isNotEmpty && user != null) {
      await _auth.updateUser(UserAttributes(data: {'full_name': name}));
      await _client
          .from('profiles')
          .update({'full_name': name})
          .eq('id', user.id)
          .isFilter('full_name', null);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) => _auth.resetPasswordForEmail(
    email.trim(),
    redirectTo: Env.authRedirectUrl,
  );

  @override
  Future<void> updatePassword(String password) =>
      _auth.updateUser(UserAttributes(password: password));

  @override
  Future<void> signOut() async {
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Not signed in with Google; nothing to clear.
      }
    }
    await _auth.signOut();
  }

  @override
  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }

  @override
  Future<void> updateProfile(String userId, Json fields) =>
      _client.from('profiles').update(fields).eq('id', userId);

  static String _randomNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
