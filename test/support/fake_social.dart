import 'package:pasyarph/data/models/post.dart';
import 'package:pasyarph/data/models/profile.dart';
import 'package:pasyarph/data/repositories/social_repository.dart';

/// In-memory likes, comments, riders and follows, with switchable failures.
class FakeSocialRepository implements SocialRepository {
  FakeSocialRepository({
    this.userId = 'me',
    List<Comment>? comments,
    Map<String, RiderProfile>? riders,
  }) : stored = comments ?? [],
       riders = riders ?? {};

  @override
  final String? userId;

  final List<Comment> stored;
  final Map<String, RiderProfile> riders;
  final likes = <String>{};
  final follows = <String>{};
  final calls = <String>[];

  /// Next call of this kind throws this.
  SocialException? failNext;

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  Future<void> like(String postId) async {
    calls.add('like:$postId');
    _maybeFail();
    likes.add(postId);
  }

  @override
  Future<void> unlike(String postId) async {
    calls.add('unlike:$postId');
    _maybeFail();
    likes.remove(postId);
  }

  @override
  Future<List<Comment>> comments(
    String postId, {
    DateTime? after,
    int limit = 30,
  }) async {
    calls.add('comments:${after?.toIso8601String() ?? 'start'}');
    _maybeFail();
    return stored
        .where((c) => c.postId == postId)
        .where((c) => after == null || c.createdAt.isAfter(after))
        .take(limit)
        .toList();
  }

  @override
  Future<Comment> addComment(String postId, String body) async {
    calls.add('add:$body');
    _maybeFail();
    final c = Comment(
      id: 'new-${stored.length}',
      postId: postId,
      authorId: userId!,
      body: body,
      createdAt: stored.isEmpty
          ? DateTime.utc(2026, 10, 19, 6)
          : stored.last.createdAt.add(const Duration(minutes: 1)),
      author: ProfileSummary(id: userId!, displayName: 'Mark Estrada'),
    );
    stored.add(c);
    return c;
  }

  @override
  Future<void> deleteComment(String commentId) async {
    calls.add('delete:$commentId');
    _maybeFail();
    stored.removeWhere((c) => c.id == commentId);
  }

  @override
  Future<RiderProfile?> rider(String id) async {
    calls.add('rider:$id');
    _maybeFail();
    return riders[id];
  }

  @override
  Future<void> follow(String id) async {
    calls.add('follow:$id');
    _maybeFail();
    follows.add(id);
  }

  @override
  Future<void> unfollow(String id) async {
    calls.add('unfollow:$id');
    _maybeFail();
    follows.remove(id);
  }
}

/// [n] comments on [postId], a minute apart, alternating two riders.
List<Comment> threadOf(String postId, int n, {String mine = 'me'}) => [
  for (var i = 0; i < n; i++)
    Comment(
      id: 'c$i',
      postId: postId,
      authorId: i.isEven ? 'jun' : mine,
      body: 'Comment $i',
      createdAt: DateTime.utc(2026, 10, 19, 5).add(Duration(minutes: i)),
      author: ProfileSummary(
        id: i.isEven ? 'jun' : mine,
        displayName: i.isEven ? 'Jun Mendoza' : 'Mark Estrada',
      ),
    ),
];
