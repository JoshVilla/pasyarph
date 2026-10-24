import 'package:flutter/foundation.dart';

import '../../../data/models/post.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/me_repository.dart';
import '../../../data/repositories/ride_history_repository.dart';
import '../../../data/repositories/social_repository.dart';
import '../me_rules.dart';

/// The Me tab's totals, follower counts and Rides grid. Reloads when a
/// ride is saved, synced or posted, so the totals change right after a
/// ride.
class MeController extends ChangeNotifier {
  MeController({
    required MeRepository me,
    required FeedRepository feed,
    required RideHistoryRepository rides,
    required String? userId,
    SocialRepository? social,
  }) : _me = me,
       _feed = feed,
       _rides = rides,
       _social = social,
       _userId = userId {
    _rides.revision.addListener(load);
  }

  final MeRepository _me;
  final FeedRepository _feed;
  final RideHistoryRepository _rides;
  final SocialRepository? _social;
  final String? _userId;

  int _followers = 0;
  int _following = 0;

  int get followers => _followers;
  int get following => _following;

  RiderTotals _serverTotals = RiderTotals.zero;
  RiderTotals _totals = RiderTotals.zero;
  List<FeedPost>? _posts;
  String? _error;
  bool _disposed = false;

  RiderTotals get totals => _totals;

  /// Null until loaded.
  List<FeedPost>? get posts => _posts;
  String? get error => _error;

  /// Totals and posts. Safe to call again (pull to refresh).
  Future<void> load() async {
    final uid = _userId;
    String? error;
    try {
      _serverTotals = await _me.totals();
    } on MeException catch (e) {
      error = e.message;
    }
    final social = _social;
    if (uid != null && social != null) {
      try {
        final me = await social.rider(uid);
        _followers = me?.followerCount ?? _followers;
        _following = me?.followingCount ?? _following;
      } on SocialException {
        // Counts stay as they were; the rest still loads.
      }
    }
    final local = await _rides.all();
    List<FeedPost>? posts = _posts;
    if (uid != null) {
      try {
        posts = postsOnly(await _feed.page(FeedScope.rider(uid), limit: 50));
      } on FeedException catch (e) {
        error ??= e.message;
      }
    }
    if (_disposed) return;
    _totals = withUnsyncedRides(_serverTotals, local);
    _posts = posts ?? (error == null ? const [] : null);
    _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _rides.revision.removeListener(load);
    super.dispose();
  }
}
