import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/features/auth/auth_errors.dart';
import 'package:pasyarph/features/auth/auth_validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('AuthValidators', () {
    test('email', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('juan'), isNotNull);
      expect(AuthValidators.email('juan@mail'), isNotNull);
      expect(AuthValidators.email(' juan@mail.ph '), isNull);
    });

    test('new password needs 8 characters', () {
      expect(AuthValidators.newPassword(''), 'Enter a password.');
      expect(AuthValidators.newPassword('1234567'), contains('8'));
      expect(AuthValidators.newPassword('12345678'), isNull);
    });

    test('login password only needs a value', () {
      expect(AuthValidators.loginPassword(''), isNotNull);
      expect(AuthValidators.loginPassword('x'), isNull);
    });

    test('full name', () {
      expect(AuthValidators.fullName(' '), isNotNull);
      expect(AuthValidators.fullName('J'), isNotNull);
      expect(AuthValidators.fullName('Juan Dela Cruz'), isNull);
    });

    test('confirm password', () {
      expect(AuthValidators.confirmPassword('a', 'b'), isNotNull);
      expect(AuthValidators.confirmPassword('abc', 'abc'), isNull);
    });
  });

  group('friendlyAuthError', () {
    test('maps Supabase error codes', () {
      expect(
        friendlyAuthError(
          const AuthApiException(
            'x',
            statusCode: '400',
            code: 'invalid_credentials',
          ),
        ),
        'Wrong email or password.',
      );
      expect(
        friendlyAuthError(
          const AuthApiException(
            'x',
            statusCode: '400',
            code: 'email_not_confirmed',
          ),
        ),
        contains('Confirm your email'),
      );
      expect(
        friendlyAuthError(
          const AuthApiException(
            'x',
            statusCode: '422',
            code: 'user_already_exists',
          ),
        ),
        contains('already exists'),
      );
    });

    test('recognises no internet', () {
      expect(
        friendlyAuthError(const SocketException('Failed host lookup')),
        contains('No internet'),
      );
      expect(
        friendlyAuthError(AuthRetryableFetchException(message: 'x')),
        contains('No internet'),
      );
    });

    test('server errors and unknowns', () {
      expect(
        friendlyAuthError(const AuthApiException('x', statusCode: '503')),
        contains('trouble'),
      );
      expect(
        friendlyAuthError(StateError('?')),
        'Something went wrong. Try again.',
      );
      expect(
        friendlyAuthError(const SignInNotConfigured('Google')),
        'Google sign-in isn\'t set up yet.',
      );
    });
  });
}
