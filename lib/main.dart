import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/location/location_permission.dart';
import 'core/location/location_provider.dart';
import 'core/location/position_source.dart';
import 'core/notifications/ride_notifier.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/avatar_repository.dart';
import 'data/repositories/feed_repository.dart';
import 'data/repositories/post_repository.dart';
import 'data/repositories/ride_history_repository.dart';
import 'data/repositories/route_repository.dart';
import 'data/repositories/social_repository.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/feed/providers/feed_provider.dart';
import 'features/post/post_draft.dart';
import 'features/ride/providers/loop_preview_provider.dart';
import 'features/ride/providers/ride_session_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.ensureConfigured();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
  final client = Supabase.instance.client;

  runApp(
    MultiProvider(
      providers: [
        Provider<AvatarRepository>(
          create: (_) => SupabaseAvatarRepository(client),
        ),
        Provider<RouteRepository>(
          create: (_) => SupabaseRouteRepository(client),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              LoopPreviewProvider(context.read<RouteRepository>()),
        ),
        Provider<LocationPermissionService>(
          create: (_) => const GeolocatorPermissionService(),
        ),
        ChangeNotifierProvider(
          create: (context) => LocationProvider(
            permissions: context.read<LocationPermissionService>(),
            positions: const GeolocatorPositionSource(),
          ),
        ),
        Provider<RideNotifier>(create: (_) => LocalRideNotifier()),
        Provider<RideHistoryRepository>(
          create: (_) => LocalRideHistoryRepository(
            uploader: SupabaseRideUploader(client),
          ),
        ),
        Provider<PostRepository>(create: (_) => SupabasePostRepository(client)),
        Provider<PostDraftStore>(create: (_) => const LocalPostDraftStore()),
        Provider<FeedRepository>(create: (_) => SupabaseFeedRepository(client)),
        Provider<SocialRepository>(
          create: (_) => SupabaseSocialRepository(client),
        ),
        ChangeNotifierProvider(
          create: (context) => RideSessionProvider(
            location: context.read<LocationProvider>(),
            notifier: context.read<RideNotifier>(),
            history: context.read<RideHistoryRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(SupabaseAuthRepository(client)),
        ),
        ChangeNotifierProvider(
          create: (context) => FeedProvider(
            feed: context.read<FeedRepository>(),
            social: context.read<SocialRepository>(),
            location: context.read<LocationProvider>(),
          ),
        ),
      ],
      child: const PasyarApp(),
    ),
  );
}
