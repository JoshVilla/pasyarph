import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/avatar_repository.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/check_email_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/welcome_screen.dart';
import '../data/repositories/loop_repository.dart';
import '../data/repositories/route_repository.dart';
import '../features/create/providers/create_loop_controller.dart';
import '../features/create/screens/create_loop_screen.dart';
import '../features/dev/screens/widget_gallery_screen.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/me/screens/me_screen.dart';
import '../features/onboarding/providers/onboarding_provider.dart';
import '../features/onboarding/screens/onboarding_location_screen.dart';
import '../features/onboarding/screens/onboarding_profile_screen.dart';
import '../features/post/screens/post_loop_screen.dart';
import '../features/ride/screens/loop_preview_screen.dart';
import '../features/ride/screens/ride_screen.dart';
import '../features/ride/screens/ride_session_screen.dart';
import 'auth_redirect.dart';
import 'env.dart';
import 'location/location_permission.dart';
import 'widgets/app_shell.dart';

abstract final class Routes {
  static const ride = '/ride';
  static const feed = '/feed';
  static const me = '/me';

  /// Create a loop: full screen over the tabs, pushed by the Create tab.
  static const create = '/create';

  /// Full screen over the tabs; pushed from Ride after GENERATE LOOP.
  static const loopPreview = '/preview';

  /// A ride navigated in Google Maps; replaces the preview.
  static const rideSession = '/riding';

  /// Posting a finished ride (from the ride summary or the Me tab).
  static const postRide = '/post/:rideId';
  static String post(String rideId) => '/post/$rideId';

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
      // Both onboarding steps share one draft, so Back keeps what was typed.
      ShellRoute(
        builder: (context, state, child) => ChangeNotifierProvider(
          create: (context) => OnboardingProvider(
            auth: context.read<AuthProvider>(),
            avatars: context.read<AvatarRepository>(),
            location: context.read<LocationPermissionService>(),
          ),
          child: child,
        ),
        routes: [
          GoRoute(
            path: AuthRoutes.onboardingProfile,
            builder: (context, state) => const OnboardingProfileScreen(),
          ),
          GoRoute(
            path: AuthRoutes.onboardingLocation,
            builder: (context, state) => const OnboardingLocationScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.loopPreview,
        builder: (context, state) => const LoopPreviewScreen(),
      ),
      GoRoute(
        path: Routes.rideSession,
        builder: (context, state) => const RideSessionScreen(),
      ),
      GoRoute(
        path: Routes.create,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => CreateLoopController(
            routes: context.read<RouteRepository>(),
            loops: context.read<LoopRepository>(),
          ),
          child: const CreateLoopScreen(),
        ),
      ),
      GoRoute(
        path: Routes.postRide,
        builder: (context, state) =>
            PostLoopScreen(rideId: state.pathParameters['rideId']!),
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
