import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/location/location_permission.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/avatar_repository.dart';
import 'features/auth/providers/auth_provider.dart';

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
        Provider<LocationPermissionService>(
          create: (_) => const GeolocatorPermissionService(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(SupabaseAuthRepository(client)),
        ),
      ],
      child: const PasyarApp(),
    ),
  );
}
