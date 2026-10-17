import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Build-time configuration passed with `--dart-define` or
/// `--dart-define-from-file=env/<flavor>.json`. See README.md.
class Env {
  Env._();

  /// True when built with `--flavor dev`. Gates dev-only screens.
  static bool get isDev => appFlavor == 'dev';

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Tile URL template, e.g.
  /// `https://api.maptiler.com/maps/streets-v4/{z}/{x}/{y}.png?key={key}`.
  static const mapTileUrl = String.fromEnvironment('MAP_TILE_URL');
  static const mapTileKey = String.fromEnvironment('MAP_TILE_KEY');

  /// Optional. OAuth client IDs from Google Cloud. The web client ID is the
  /// one configured in Supabase (Auth → Providers → Google). Without it the
  /// Google button shows a "not set up" message instead of signing in.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  /// Android application ID / custom URL scheme for this flavor. Auth emails
  /// and OAuth redirect to `<appId>://auth-callback`.
  static String get appId =>
      isDev ? 'com.pasyarph.app.dev' : 'com.pasyarph.app';

  static String get authRedirectUrl => '$appId://auth-callback';

  static const _values = {
    'SUPABASE_URL': supabaseUrl,
    'SUPABASE_ANON_KEY': supabaseAnonKey,
    'MAP_TILE_URL': mapTileUrl,
    'MAP_TILE_KEY': mapTileKey,
  };

  /// Throws [MissingEnvError] if any value was not provided at build time.
  /// Call once at startup, before anything reads [Env].
  static void ensureConfigured() => check(_values);

  @visibleForTesting
  static void check(Map<String, String> values) {
    final missing = [
      for (final entry in values.entries)
        if (entry.value.trim().isEmpty) entry.key,
    ];
    if (missing.isNotEmpty) throw MissingEnvError(missing);
  }
}

class MissingEnvError extends Error {
  MissingEnvError(this.keys);

  final List<String> keys;

  @override
  String toString() =>
      'MissingEnvError: missing ${keys.join(', ')}.\n'
      'Run with --dart-define-from-file=env/dev.json (or env/prod.json). '
      'Copy env/example.json to create it. See README.md.';
}
