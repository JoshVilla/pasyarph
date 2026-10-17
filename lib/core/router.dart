import 'package:go_router/go_router.dart';

import '../features/create/screens/create_screen.dart';
import '../features/dev/screens/widget_gallery_screen.dart';
import '../features/feed/screens/feed_screen.dart';
import '../features/me/screens/me_screen.dart';
import '../features/ride/screens/ride_screen.dart';
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

GoRouter createRouter({bool? includeDevRoutes}) => GoRouter(
  initialLocation: Routes.ride,
  routes: [
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
    if (includeDevRoutes ?? Env.isDev)
      GoRoute(
        path: Routes.devWidgets,
        builder: (context, state) => const WidgetGalleryScreen(),
      ),
  ],
);
