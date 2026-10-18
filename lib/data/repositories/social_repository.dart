import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/post.dart';

/// Why a like or comment failed, with a message safe to show riders.
class SocialException implements Exception {
  const SocialException(this.code, this.message);

  final String code;
  final String message;

  static const offline = SocialException(
    'offline',
    "Couldn't reach Pasyar. Check your connection and try again.",
  );
  static const blocked = SocialException(
    'comment_blocked',
    "Let's keep it friendly: that comment has words we don't allow.",
  );
  static const duplicate = SocialException(
    'comment_duplicate',
    'You already posted that comment.',
  );

  @override
  String toString() => 'SocialException($code)';
}

abstract interface class SocialRepository {
  /// The signed-in user, to tell own comments apart.
  String? get userId;

  Future<void> like(String postId);
  Future<void> unlike(String postId);

  /// Oldest first; pass the last comment's createdAt as [after] for the
  /// next page.
  Future<List<Comment>> comments(
    String postId, {
    DateTime? after,
    int limit = 30,
  });

  /// Throws [SocialException.blocked] / [SocialException.duplicate] when
  /// the comment rules refuse it.
  Future<Comment> addComment(String postId, String body);
  Future<void> deleteComment(String commentId);
}

class SupabaseSocialRepository implements SocialRepository {
  SupabaseSocialRepository(this._client);

  final SupabaseClient _client;

  @override
  String? get userId => _client.auth.currentUser?.id;

  Future<T> _guard<T>(String what, Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      debugPrint('social: $what failed: ${e.code} ${e.message}');
      if (e.message.contains('comment_blocked')) throw SocialException.blocked;
      if (e.message.contains('comment_duplicate')) {
        throw SocialException.duplicate;
      }
      throw SocialException.offline;
    } on Exception catch (e) {
      debugPrint('social: $what failed: $e');
      throw SocialException.offline;
    }
  }

  @override
  Future<void> like(String postId) => _guard('like', () async {
    try {
      await _client.from('likes').insert({'post_id': postId});
    } on PostgrestException catch (e) {
      // Already liked (a double tap or a retry): that's the goal anyway.
      if (e.code != '23505') rethrow;
    }
  });

  @override
  Future<void> unlike(String postId) => _guard(
    'unlike',
    () => _client
        .from('likes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId ?? ''),
  );

  @override
  Future<List<Comment>> comments(
    String postId, {
    DateTime? after,
    int limit = 30,
  }) => _guard('comments', () async {
    var q = _client
        .from('comments')
        .select(Comment.columns)
        .eq('post_id', postId);
    if (after != null) q = q.gt('created_at', after.toUtc().toIso8601String());
    final rows = await q
        .order('created_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit);
    return [for (final r in rows) Comment.fromJson(r)];
  });

  @override
  Future<Comment> addComment(String postId, String body) =>
      _guard('add comment', () async {
        final row = await _client
            .from('comments')
            .insert({'post_id': postId, 'body': body})
            .select(Comment.columns)
            .single();
        return Comment.fromJson(row);
      });

  @override
  Future<void> deleteComment(String commentId) => _guard(
    'delete comment',
    () => _client.from('comments').delete().eq('id', commentId),
  );
}
