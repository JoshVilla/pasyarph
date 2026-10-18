import 'package:flutter/foundation.dart';

import '../../../data/models/post.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/social_repository.dart';

/// One post's comments sheet: pages of [pageSize] oldest first, posting,
/// and deleting your own (removed at once, put back on failure).
class CommentsController extends ChangeNotifier {
  CommentsController({
    required this.postId,
    required SocialRepository social,
    required int count,
    this.pageSize = 30,
  }) : _social = social,
       _count = count;

  final String postId;
  final SocialRepository _social;
  final int pageSize;

  final _comments = <Comment>[];

  /// Your new comments while older pages are still unloaded: shown at the
  /// end, until paging reaches them (the cursor stays on [_comments]).
  final _ownTail = <Comment>[];
  int _count;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _sending = false;
  String? _error;
  bool _disposed = false;

  List<Comment> get comments {
    final seen = {for (final c in _comments) c.id};
    return List.unmodifiable([
      ..._comments,
      ..._ownTail.where((c) => !seen.contains(c.id)),
    ]);
  }

  /// Total on the post, for the header and the feed card.
  int get count => _count;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  bool get sending => _sending;

  /// Why the last action failed (shown under the input).
  String? get error => _error;

  /// The oldest comment, for the card preview; null when there are none.
  FeedComment? get firstComment {
    if (_comments.isEmpty) return null;
    final c = _comments.first;
    return FeedComment(
      author: c.author ?? ProfileSummary(id: c.authorId),
      body: c.body,
    );
  }

  bool isMine(Comment c) => c.authorId == _social.userId;

  Future<void> load() async {
    _loading = true;
    _error = null;
    _notify();
    try {
      final page = await _social.comments(postId, limit: pageSize);
      _comments
        ..clear()
        ..addAll(page);
      _ownTail.clear();
      _hasMore = page.length >= pageSize;
    } on SocialException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _comments.isEmpty) return;
    _loadingMore = true;
    _notify();
    try {
      final page = await _social.comments(
        postId,
        after: _comments.last.createdAt,
        limit: pageSize,
      );
      final seen = {for (final c in _comments) c.id};
      _comments.addAll(page.where((c) => !seen.contains(c.id)));
      _hasMore = page.length >= pageSize;
    } on SocialException catch (e) {
      _error = e.message;
    } finally {
      _loadingMore = false;
      _notify();
    }
  }

  /// Posts [text]; true when it went through (clear the input then).
  Future<bool> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return false;
    _sending = true;
    _error = null;
    _notify();
    try {
      final c = await _social.addComment(postId, body);
      // Newest goes last: straight into the list once every page is in.
      (_hasMore ? _ownTail : _comments).add(c);
      _count++;
      return true;
    } on SocialException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _sending = false;
      _notify();
    }
  }

  Future<void> delete(Comment c) async {
    final list = _comments.contains(c) ? _comments : _ownTail;
    final i = list.indexOf(c);
    if (i < 0 || !isMine(c)) return;
    list.removeAt(i);
    _count--;
    _error = null;
    _notify();
    try {
      await _social.deleteComment(c.id);
    } on SocialException catch (e) {
      list.insert(i, c);
      _count++;
      _error = e.message;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
