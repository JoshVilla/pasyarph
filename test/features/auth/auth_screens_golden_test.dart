import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/features/auth/providers/auth_provider.dart';
import 'package:pasyarph/features/auth/screens/check_email_screen.dart';
import 'package:pasyarph/features/auth/screens/forgot_password_screen.dart';
import 'package:pasyarph/features/auth/screens/login_screen.dart';
import 'package:pasyarph/features/auth/screens/register_screen.dart';
import 'package:pasyarph/features/auth/screens/reset_password_screen.dart';
import 'package:pasyarph/features/auth/screens/welcome_screen.dart';
import 'package:provider/provider.dart';

import '../../support/fake_auth_repository.dart';

/// Screens at the mockup size, 390 × 844, to compare with
/// design/screenshots/07-welcome.png, 08-login.png and 09-register.png.
const _screen = BoxConstraints.tightFor(width: 390, height: 844);

Widget _phone(Widget screen) => ChangeNotifierProvider(
  create: (_) => AuthProvider(FakeAuthRepository()),
  child: screen,
);

void main() {
  group('Golden', () {
    goldenTest(
      'Welcome (07)',
      fileName: 'welcome',
      constraints: _screen,
      builder: () => _phone(const WelcomeScreen()),
    );

    goldenTest(
      'Log in (08)',
      fileName: 'login',
      constraints: _screen,
      builder: () => _phone(const LoginScreen()),
    );

    goldenTest(
      'Register (09)',
      fileName: 'register',
      constraints: _screen,
      builder: () => _phone(const RegisterScreen()),
    );

    goldenTest(
      'Forgot password (no mockup)',
      fileName: 'forgot_password',
      constraints: _screen,
      builder: () =>
          _phone(const ForgotPasswordScreen(initialEmail: 'juan@email.com')),
    );

    goldenTest(
      'Check your email (no mockup)',
      fileName: 'check_email',
      constraints: _screen,
      pumpBeforeTest: pumpOnce,
      builder: () => _phone(const CheckEmailScreen(email: 'juan@email.com')),
    );

    goldenTest(
      'Set new password (no mockup)',
      fileName: 'reset_password',
      constraints: _screen,
      builder: () => _phone(const ResetPasswordScreen()),
    );
  });
}
