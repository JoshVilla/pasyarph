import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/json.dart';
import '../models/post.dart';

/// Why the feed couldn't load, with a message safe to show riders.
class FeedException implements Exception {
  const FeedException(this.message);

  final String message;

  static const offline = FeedException(
    "Couldn't load the feed. Check your connection and pull to refresh.",
  );
}

abstract interface class FeedRepository {
  /// Posts with their stop within [radiusM] of [near], newest first. Pass
  /// the last post's createdAt as [before] for the next page. Throws
  /// [FeedException].
  Future<List<FeedPost>> near(
    LatLng near, {
    DateTime? before,
    int limit = 20,
    double radiusM = feedRadiusM,
  });

  /// A post photo (storage path in post-photos), cached on the phone.
  ImageProvider photo(String storagePath);

  /// A profile picture by URL, cached on the phone.
  ImageProvider avatar(String url);
}

/// "Near you" reach.
const feedRadiusM = 100000.0;

class SupabaseFeedRepository implements FeedRepository {
  SupabaseFeedRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<FeedPost>> near(
    LatLng near, {
    DateTime? before,
    int limit = 20,
    double radiusM = feedRadiusM,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'feed_near',
        params: {
          'lat': near.latitude,
          'lng': near.longitude,
          'radius_m': radiusM,
          'page_limit': limit,
          'page_cursor': before?.toUtc().toIso8601String(),
        },
      );
      return [for (final r in rows) FeedPost.fromJson(r as Json)];
    } on Exception catch (e) {
      debugPrint('feed: feed_near failed: $e');
      throw FeedException.offline;
    }
  }

  @override
  ImageProvider photo(String storagePath) => CachedNetworkImageProvider(
    _client.storage.from('post-photos').getPublicUrl(storagePath),
  );

  @override
  ImageProvider avatar(String url) => CachedNetworkImageProvider(url);
}
