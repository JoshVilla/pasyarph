import 'package:go_router/go_router.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/check_email_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../features/create/screens/create_screen.dart';
import '../features/dev/screens/widget_gallery_screen.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/me/screens/me_screen.dart';
import '../features/onboarding/screens/onboarding_placeholder_screen.dart';
import '../features/ride/screens/ride_screen.dart';
import 'auth_redirect.dart';
import 'env.dart';
import 'widgets/app_shell.dart';

abstract final class Routes {
  static const ride = '/ride';
  static const feed = '/feed';
  static const create = '/create';
  static const me = '/me';

  /// Dev flavor only.
  static const devWidgets = '/dev/widgets';
}

GoRouter createRouter({required AuthProvider auth, bool? includeDevRoutes}) {
  final dev = includeDevRoutes ?? Env.isDev;
  return GoRouter(
    initialLocation: Routes.ride,
    refreshListenable: auth,
    redirect: (context, state) => authRedirect(
      status: auth.status,
      onboardingCompleted: auth.onboardingCompleted,
      passwordRecovery: auth.passwordRecovery,
      location: state.matchedLocation,
      home: Routes.ride,
      alwaysAllowed: {if (dev) Routes.devWidgets},
    ),
    routes: [
      GoRoute(
        path: AuthRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AuthRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AuthRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AuthRoutes.forgotPassword,
        builder: (context, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'],
        ),
      ),
      GoRoute(
        path: AuthRoutes.checkEmail,
        builder: (context, state) =>
            CheckEmailScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: AuthRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AuthRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AuthRoutes.onboardingProfile,
        builder: (context, state) => const OnboardingPlaceholderScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.ride,
                builder: (context, state) => const RideScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.feed,
                builder: (context, state) => const FeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.create,
                builder: (context, state) => const CreateScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.me,
                builder: (context, state) => const MeScreen(),
              ),
            ],
          ),
        ],
      ),
      if (dev)
        GoRoute(
          path: Routes.devWidgets,
          builder: (context, state) => const WidgetGalleryScreen(),
        ),
    ],
  );
}
