import '../features/auth/providers/auth_provider.dart';

abstract final class AuthRoutes {
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const checkEmail = '/check-email';
  static const resetPassword = '/reset-password';
  static const splash = '/splash';
  static const onboardingProfile = '/onboarding/profile';
  static const onboardingLocation = '/onboarding/location';

  static const signedOutOnly = {
    welcome,
    login,
    register,
    forgotPassword,
    checkEmail,
  };
}

/// Where to send the user for [location], or null to stay. Pure so the
/// rules can be unit tested:
/// - signed out → /welcome (Welcome, Log in, Register, Forgot password and
///   Check your email are allowed);
/// - opened a password reset link → /reset-password;
/// - signed in, profile loading or failed → /splash;
/// - signed in, onboarding not done → /onboarding/profile;
/// - otherwise away from the auth screens to [home].
String? authRedirect({
  required AuthStatus status,
  required bool onboardingCompleted,
  required bool passwordRecovery,
  required String location,
  required String home,
  Set<String> alwaysAllowed = const {},
}) {
  if (alwaysAllowed.contains(location)) return null;

  if (status == AuthStatus.signedOut) {
    return AuthRoutes.signedOutOnly.contains(location)
        ? null
        : AuthRoutes.welcome;
  }

  if (passwordRecovery) {
    return location == AuthRoutes.resetPassword
        ? null
        : AuthRoutes.resetPassword;
  }

  if (status != AuthStatus.signedIn) {
    return location == AuthRoutes.splash ? null : AuthRoutes.splash;
  }

  final inOnboarding = location.startsWith('/onboarding');
  if (!onboardingCompleted) {
    return inOnboarding ? null : AuthRoutes.onboardingProfile;
  }

  final onAuthScreen =
      AuthRoutes.signedOutOnly.contains(location) ||
      location == AuthRoutes.splash ||
      location == AuthRoutes.resetPassword ||
      inOnboarding;
  return onAuthScreen ? home : null;
}
