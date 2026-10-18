import 'package:latlong2/latlong.dart';

import '../geo/geo_codec.dart';
import 'json.dart';
import 'loop.dart';
import 'profile.dart';

/// Row of `posts`.
class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.loopId,
    required this.stopLocation,
    required this.createdAt,
    this.caption,
  });

  final String id;
  final String authorId;
  final String loopId;
  final String? caption;

  /// GPS-verified location at the main stop.
  final LatLng stopLocation;
  final DateTime createdAt;

  factory Post.fromJson(Json json) => Post(
    id: json['id'] as String,
    authorId: json['author_id'] as String,
    loopId: json['loop_id'] as String,
    caption: json['caption'] as String?,
    stopLocation: GeoCodec.parsePoint(json['stop_location'] as Object),
    createdAt: parseTimestamp(json['created_at']),
  );

  /// Insert payload. `author_id` defaults to the signed-in user.
  static Json insertJson({
    required String loopId,
    required LatLng stopLocation,
    String? caption,
  }) => {
    'loop_id': loopId,
    'caption': caption,
    'stop_location': GeoCodec.pointToEwkt(stopLocation),
  };
}

/// Row of `post_photos`. A post has at most 10, at positions 0-9.
class PostPhoto {
  const PostPhoto({
    required this.id,
    required this.postId,
    required this.storagePath,
    required this.position,
    this.width,
    this.height,
  });

  static const maxPerPost = 10;

  final String id;
  final String postId;

  /// Path inside the post-photos bucket: `<user_id>/<post_id>/<n>.jpg`.
  final String storagePath;
  final int position;
  final int? width;
  final int? height;

  factory PostPhoto.fromJson(Json json) => PostPhoto(
    id: json['id'] as String,
    postId: json['post_id'] as String,
    storagePath: json['storage_path'] as String,
    position: (json['position'] as num).toInt(),
    width: toIntOrNull(json['width']),
    height: toIntOrNull(json['height']),
  );

  Json toInsertJson() => {
    'post_id': postId,
    'storage_path': storagePath,
    'position': position,
    'width': width,
    'height': height,
  };
}

/// Row of `likes`.
class Like {
  const Like({
    required this.postId,
    required this.userId,
    required this.createdAt,
  });

  final String postId;
  final String userId;
  final DateTime createdAt;

  factory Like.fromJson(Json json) => Like(
    postId: json['post_id'] as String,
    userId: json['user_id'] as String,
    createdAt: parseTimestamp(json['created_at']),
  );
}

/// Row of `comments`.
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.author,
  });

  /// Embedded author columns, for selects with `author:profiles(...)`.
  static const columns =
      'id,post_id,author_id,body,created_at,'
      'author:profiles!comments_author_id_fkey(id,display_name,avatar_url)';

  final String id;
  final String postId;
  final String authorId;
  final String body;
  final DateTime createdAt;

  /// Name and picture, when selected with [columns].
  final ProfileSummary? author;

  factory Comment.fromJson(Json json) => Comment(
    id: json['id'] as String,
    postId: json['post_id'] as String,
    authorId: json['author_id'] as String,
    body: json['body'] as String,
    createdAt: parseTimestamp(json['created_at']),
    author: switch (json['author']) {
      final Json a => ProfileSummary.fromJson(a),
      _ => null,
    },
  );
}

/// A row from the `feed_near` RPC: post, author, photos, loop and counts.
class FeedPost {
  const FeedPost({
    required this.id,
    required this.createdAt,
    required this.stopLocation,
    required this.distanceAwayM,
    required this.author,
    required this.photos,
    required this.loop,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    this.caption,
    this.firstComment,
  });

  final String id;
  final String? caption;
  final DateTime createdAt;
  final LatLng stopLocation;
  final double distanceAwayM;
  final ProfileSummary author;
  final List<PostPhoto> photos;
  final Loop loop;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  /// The oldest comment, previewed under the card.
  final FeedComment? firstComment;

  FeedPost copyWith({
    int? likeCount,
    bool? likedByMe,
    int? commentCount,
    FeedComment? Function()? firstComment,
  }) => FeedPost(
    id: id,
    caption: caption,
    createdAt: createdAt,
    stopLocation: stopLocation,
    distanceAwayM: distanceAwayM,
    author: author,
    photos: photos,
    loop: loop,
    likeCount: likeCount ?? this.likeCount,
    likedByMe: likedByMe ?? this.likedByMe,
    commentCount: commentCount ?? this.commentCount,
    firstComment: firstComment == null ? this.firstComment : firstComment(),
  );

  factory FeedPost.fromJson(Json json) => FeedPost(
    id: json['id'] as String,
    caption: json['caption'] as String?,
    createdAt: parseTimestamp(json['created_at']),
    stopLocation: GeoCodec.parsePoint(json['stop_location'] as Object),
    distanceAwayM: (json['distance_away_m'] as num).toDouble(),
    author: ProfileSummary.fromJson(json['author'] as Json),
    photos: [
      for (final p in json['photos'] as List) PostPhoto.fromJson(p as Json),
    ],
    loop: Loop.fromJson(json['loop'] as Json),
    likeCount: (json['like_count'] as num).toInt(),
    commentCount: (json['comment_count'] as num).toInt(),
    likedByMe: json['liked_by_me'] as bool,
    firstComment: switch (json['first_comment']) {
      final Json c => FeedComment.fromJson(c),
      _ => null,
    },
  );
}

/// A comment as the feed shows it: author and text.
class FeedComment {
  const FeedComment({required this.author, required this.body});

  final ProfileSummary author;
  final String body;

  factory FeedComment.fromJson(Json json) => FeedComment(
    author: ProfileSummary.fromJson(json['author'] as Json),
    body: json['body'] as String,
  );
}
