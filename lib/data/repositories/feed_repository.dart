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

/// Which posts a feed shows besides "Near you" (`feed_page` scopes).
class FeedScope {
  const FeedScope._(this.name, [this.target]);

  /// Posts near the rider (`feed_near`).
  static const near = FeedScope._('near');

  /// Riders the rider follows.
  static const following = FeedScope._('following');

  /// Club loops of the rider's clubs.
  static const myClubs = FeedScope._('clubs');

  /// One club's page.
  const FeedScope.club(String clubId) : this._('club', clubId);

  /// One rider's profile.
  const FeedScope.rider(String userId) : this._('rider', userId);

  /// The `feed_page` scope.
  final String name;

  /// Club or rider id.
  final String? target;

  @override
  bool operator ==(Object other) =>
      other is FeedScope && other.name == name && other.target == target;

  @override
  int get hashCode => Object.hash(name, target);

  @override
  String toString() => 'FeedScope($name${target == null ? '' : ', $target'})';
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

  /// Posts and loops shared without a post in [scope] (not
  /// [FeedScope.near]), newest first. [near] only fills in distances. Throws
  /// [FeedException].
  Future<List<FeedPost>> page(
    FeedScope scope, {
    LatLng? near,
    DateTime? before,
    int limit = 20,
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
  Future<List<FeedPost>> page(
    FeedScope scope, {
    LatLng? near,
    DateTime? before,
    int limit = 20,
  }) async {
    assert(scope != FeedScope.near, 'Use near() for the Near you feed');
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'feed_page',
        params: {
          'p_scope': scope.name,
          'p_target': scope.target,
          'lat': near?.latitude,
          'lng': near?.longitude,
          'page_limit': limit,
          'page_cursor': before?.toUtc().toIso8601String(),
        },
      );
      return [for (final r in rows) FeedPost.fromJson(r as Json)];
    } on Exception catch (e) {
      debugPrint('feed: feed_page($scope) failed: $e');
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
