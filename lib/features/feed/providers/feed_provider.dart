import 'package:flutter/foundation.dart';

import '../../../core/location/location_provider.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/feed_repository.dart';

enum FeedFilter {
  nearYou('Near you'),
  following('Following'),
  myClubs('My clubs');

  const FeedFilter(this.label);
  final String label;
}

/// The Feed tab: "Near you" posts in pages of [pageSize] (cursor = the last
/// post's time), pull to refresh. Following and My clubs come with
/// Prompt 17 and are empty until then.
class FeedProvider extends ChangeNotifier {
  FeedProvider({
    required FeedRepository feed,
    required LocationProvider location,
    this.pageSize = 20,
  }) : _feed = feed,
       _location = location;

  final FeedRepository _feed;
  final LocationProvider _location;
  final int pageSize;

  FeedFilter _filter = FeedFilter.nearYou;
  final _posts = <FeedPost>[];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _started = false;
  String? _error;
  bool _waitingForFix = false;

  FeedFilter get filter => _filter;
  List<FeedPost> get posts => List.unmodifiable(_posts);

  /// First page (or a refresh with nothing shown yet).
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  /// No position yet (permission or the phone's location is off).
  bool get needsLocation => _filter == FeedFilter.nearYou && !_location.hasFix;

  /// Loads the first page once; safe to call on every visit.
  void start() {
    if (_started) return;
    _started = true;
    refresh();
  }

  void setFilter(FeedFilter f) {
    if (_filter == f) return;
    _filter = f;
    notifyListeners();
  }

  /// Reloads from the newest post. Keeps the old posts on screen until the
  /// new page arrives (or on failure).
  Future<void> refresh() async {
    final here = _location.position;
    if (here == null || !_location.hasFix) {
      _waitForFix();
      notifyListeners();
      return;
    }
    _loading = _posts.isEmpty;
    _error = null;
    notifyListeners();
    try {
      final page = await _feed.near(here, limit: pageSize);
      _posts
        ..clear()
        ..addAll(page);
      _hasMore = page.length >= pageSize;
    } on FeedException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Next page, when the list nears its end.
  Future<void> loadMore() async {
    final here = _location.position;
    if (_loading ||
        _loadingMore ||
        !_hasMore ||
        _posts.isEmpty ||
        here == null) {
      return;
    }
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await _feed.near(
        here,
        before: _posts.last.createdAt,
        limit: pageSize,
      );
      final seen = {for (final p in _posts) p.id};
      _posts.addAll(page.where((p) => !seen.contains(p.id)));
      _hasMore = page.length >= pageSize;
    } on FeedException catch (e) {
      _error = e.message;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  /// Loads as soon as the first GPS fix arrives.
  void _waitForFix() {
    if (_waitingForFix) return;
    _waitingForFix = true;
    _location.addListener(_onLocation);
  }

  void _onLocation() {
    if (!_location.hasFix) return;
    _location.removeListener(_onLocation);
    _waitingForFix = false;
    refresh();
  }

  @override
  void dispose() {
    _location.removeListener(_onLocation);
    super.dispose();
  }
}
