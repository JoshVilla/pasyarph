import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/avatar_repository.dart';
import '../data/repositories/club_repository.dart';
import '../data/repositories/feed_repository.dart';
import '../data/repositories/social_repository.dart';
import '../features/clubs/providers/club_controller.dart';
import '../features/clubs/screens/club_screen.dart';
import '../features/clubs/screens/create_club_screen.dart';
import '../features/clubs/screens/join_club_screen.dart';
import '../features/feed/providers/feed_provider.dart';
import '../features/links/screens/loop_link_screen.dart';
import '../features/links/screens/post_link_screen.dart';
import '../features/riders/providers/rider_profile_controller.dart';
import '../features/riders/screens/rider_profile_screen.dart';
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
import '../data/repositories/me_repository.dart';
import '../data/repositories/ride_history_repository.dart';
import '../features/me/providers/me_controller.dart';
import '../features/me/screens/me_screen.dart';
import '../features/me/screens/settings_screen.dart';
import '../features/onboarding/providers/onboarding_provider.dart';
import '../features/onboarding/screens/onboarding_location_screen.dart';
import '../features/onboarding/screens/onboarding_profile_screen.dart';
import '../features/post/screens/post_loop_screen.dart';
import '../features/ride/screens/loop_preview_screen.dart';
import '../features/ride/screens/ride_screen.dart';
import '../features/ride/screens/ride_session_screen.dart';
import 'auth_redirect.dart';
import 'deep_links.dart';
import 'env.dart';
import 'location/location_permission.dart';
import 'location/location_provider.dart';
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

  /// Clubs (Prompt 17), full screen over the tabs.
  static const newClub = '/clubs/new';
  static const joinClubPath = '/clubs/join/:code';
  static String joinClub(String code) => '/clubs/join/$code';
  static const clubPath = '/clubs/:clubId';
  static String club(String id) => '/clubs/$id';

  /// Another rider's profile, from a post or a club's members.
  static const riderPath = '/riders/:userId';
  static String rider(String id) => '/riders/$id';

  /// Posting a finished ride (from the ride summary or the Me tab).
  static const postRide = '/post/:rideId';
  static String post(String rideId) => '/post/$rideId';

  /// Share links (Prompt 18), the same paths as on the web
  /// (https://pasyar.pages.dev/l/id). See AppLinks.
  static const loopLinkPath = '/l/:loopId';
  static const postLinkPath = '/p/:postId';
  static const inviteLinkPath = '/join/:code';

  /// A post by id (the post screen share links open).
  static String postLink(String id) => '/p/$id';

  /// Me tab (Prompt 19), full screen over the tabs.
  static const settings = '/settings';
  static const editProfile = '/profile/edit';

  /// Dev flavor only.
  static const devWidgets = '/dev/widgets';
}

GoRouter createRouter({required AuthProvider auth, bool? includeDevRoutes}) {
  final dev = includeDevRoutes ?? Env.isDev;
  // A link opened while signed out opens after signing in.
  final pending = PendingLink();
  return GoRouter(
    initialLocation: Routes.ride,
    refreshListenable: auth,
    redirect: (context, state) => pending.redirect(
      path: state.uri.path,
      home: Routes.ride,
      target: authRedirect(
        status: auth.status,
        onboardingCompleted: auth.onboardingCompleted,
        passwordRecovery: auth.passwordRecovery,
        location: state.matchedLocation,
        home: Routes.ride,
        alwaysAllowed: {if (dev) Routes.devWidgets},
      ),
    ),
    routes: [
      GoRoute(
        path: Routes.loopLinkPath,
        builder: (context, state) =>
            LoopLinkScreen(loopId: state.pathParameters['loopId']!),
      ),
      GoRoute(
        path: Routes.postLinkPath,
        builder: (context, state) {
          final id = state.pathParameters['postId']!;
          return ChangeNotifierProvider(
            create: (context) => _scopedFeed(context, FeedScope.post(id)),
            child: PostLinkScreen(postId: id),
          );
        },
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => OnboardingProvider(
            auth: context.read<AuthProvider>(),
            avatars: context.read<AvatarRepository>(),
            location: context.read<LocationPermissionService>(),
          ),
          child: const OnboardingProfileScreen(editing: true),
        ),
      ),
      GoRoute(
        path: Routes.inviteLinkPath,
        redirect: (context, state) =>
            Routes.joinClub(state.pathParameters['code']!.toLowerCase()),
      ),
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
        path: Routes.newClub,
        builder: (context, state) => const CreateClubScreen(),
      ),
      GoRoute(
        path: Routes.joinClubPath,
        builder: (context, state) =>
            JoinClubScreen(code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: Routes.clubPath,
        builder: (context, state) {
          final id = state.pathParameters['clubId']!;
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (context) => ClubController(
                  clubs: context.read<ClubRepository>(),
                  clubId: id,
                ),
              ),
              ChangeNotifierProvider(
                create: (context) => _scopedFeed(context, FeedScope.club(id)),
              ),
            ],
            child: const ClubScreen(),
          );
        },
      ),
      GoRoute(
        path: Routes.riderPath,
        builder: (context, state) {
          final id = state.pathParameters['userId']!;
          return MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (context) => RiderProfileController(
                  social: context.read<SocialRepository>(),
                  userId: id,
                ),
              ),
              ChangeNotifierProvider(
                create: (context) => _scopedFeed(context, FeedScope.rider(id)),
              ),
            ],
            child: const RiderProfileScreen(),
          );
        },
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
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) => MeController(
                    me: context.read<MeRepository>(),
                    feed: context.read<FeedRepository>(),
                    rides: context.read<RideHistoryRepository>(),
                    userId: context.read<AuthProvider>().user?.id,
                  ),
                  child: const MeScreen(),
                ),
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

/// Posts of one club or rider, for their page.
FeedProvider _scopedFeed(BuildContext context, FeedScope scope) => FeedProvider(
  feed: context.read<FeedRepository>(),
  social: context.read<SocialRepository>(),
  location: context.read<LocationProvider>(),
  scope: scope,
);
