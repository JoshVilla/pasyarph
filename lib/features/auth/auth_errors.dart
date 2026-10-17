import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when a sign-in was cancelled by the user (closed the Google or
/// Apple sheet). Callers should stay quiet, not show an error.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// Thrown when a provider isn't configured for this build.
class SignInNotConfigured implements Exception {
  const SignInNotConfigured(this.provider);

  final String provider;
}

/// Turns auth failures into short, friendly messages for riders.
String friendlyAuthError(Object error) {
  if (error is SignInNotConfigured) {
    return '${error.provider} sign-in isn\'t set up yet.';
  }
  if (_isOffline(error)) {
    return 'No internet connection. Check your signal and try again.';
  }
  if (error is AuthException) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'Wrong email or password.';
      case 'email_not_confirmed':
        return 'Confirm your email first. Check your inbox for the link.';
      case 'user_already_exists':
      case 'email_exists':
        return 'An account with this email already exists. Log in instead.';
      case 'weak_password':
        return 'Choose a stronger password.';
      case 'same_password':
        return 'Use a different password from your old one.';
      case 'over_email_send_rate_limit':
        return 'Too many emails sent. Wait a minute and try again.';
      case 'over_request_rate_limit':
        return 'Too many tries. Wait a minute and try again.';
      case 'user_banned':
        return 'This account is suspended.';
      case 'otp_expired':
        return 'That link has expired. Request a new one.';
    }
    final status = int.tryParse(error.statusCode ?? '');
    if (status != null && status >= 500) {
      return 'Pasyar is having trouble right now. Try again in a moment.';
    }
  }
  return 'Something went wrong. Try again.';
}

bool _isOffline(Object error) =>
    error is SocketException ||
    error is TimeoutException ||
    error is AuthRetryableFetchException ||
    (error is AuthException && error.message.contains('SocketException'));
