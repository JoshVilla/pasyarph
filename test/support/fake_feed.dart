import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/models/loop.dart';
import 'package:pasyarph/data/models/post.dart';
import 'package:pasyarph/data/models/profile.dart';
import 'package:pasyarph/data/repositories/feed_repository.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';

/// Photos named "#rrggbb" render as that solid color.
ImageProvider solidPhoto(String hex) {
  final v = int.parse(hex.substring(1), radix: 16);
  final image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(v >> 16 & 255, v >> 8 & 255, v & 255));
  return MemoryImage(img.encodePng(image));
}

/// Pages through [posts] like feed_near (newest first, cursor = createdAt).
class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository(this.posts);

  final List<FeedPost> posts;
  final calls = <DateTime?>[];
  bool fail = false;
  final _images = <String, ImageProvider>{};

  @override
  Future<List<FeedPost>> near(
    LatLng near, {
    DateTime? before,
    int limit = 20,
    double radiusM = feedRadiusM,
  }) async {
    calls.add(before);
    if (fail) throw FeedException.offline;
    return posts
        .where((p) => before == null || p.createdAt.isBefore(before))
        .take(limit)
        .toList();
  }

  @override
  ImageProvider photo(String storagePath) =>
      _images.putIfAbsent(storagePath, () => solidPhoto(storagePath));

  @override
  ImageProvider avatar(String url) => solidPhoto('#5A5F69');
}

FeedPost feedPost({
  required String id,
  required DateTime createdAt,
  String author = 'Rico Navarro',
  String loopName = 'Sunday Falls Loop',
  String? stopName,
  String? caption,
  List<String> photos = const [],
  int distanceM = 118000,
  int durationS = 13800,
  double? curviness,
  double awayM = 6000,
  LoopVisibility visibility = LoopVisibility.public,
  String? province,
  int likes = 0,
  int comments = 0,
  bool liked = false,
  FeedComment? firstComment,
}) => FeedPost(
  id: id,
  createdAt: createdAt,
  caption: caption,
  stopLocation: DemoRoutes.mainStop,
  distanceAwayM: awayM,
  author: ProfileSummary(id: 'author-$id', displayName: author),
  photos: [
    for (final (i, p) in photos.indexed)
      PostPhoto(id: '$id-$i', postId: id, storagePath: p, position: i),
  ],
  loop: Loop(
    id: 'loop-$id',
    ownerId: 'author-$id',
    name: loopName,
    source: LoopSource.generated,
    distanceM: distanceM,
    durationS: durationS,
    curvinessScore: curviness,
    visibility: visibility,
    createdAt: createdAt,
    sharedRoute: DemoRoutes.loop,
    province: province,
    mainStop: MainStop(
      location: DemoRoutes.mainStop,
      name: stopName,
      type: 'waterfall',
    ),
  ),
  likeCount: likes,
  commentCount: comments,
  likedByMe: liked,
  firstComment: firstComment,
);

/// The three posts of mockup 5, relative to [now].
List<FeedPost> mockupPosts(DateTime now) => [
  feedPost(
    id: 'p1',
    province: 'Isabela',
    createdAt: now.subtract(const Duration(hours: 2)),
    stopName: '[Stop name] Falls',
    caption:
        'Sunday loop with the club. Smooth roads after the bridge, and '
        "the falls were full from last week's rain.",
    photos: const [
      '#A8B9A0',
      '#9FB4C4',
      '#C9B79C',
      '#A8B3A0',
      '#B9C7B0',
      '#9FB4C4',
    ],
    likes: 48,
    comments: 12,
    liked: true,
    firstComment: const FeedComment(
      author: ProfileSummary(id: 'c1', displayName: 'Jun Mendoza'),
      body: 'Is the road to the falls paved all the way?',
    ),
  ),
  feedPost(
    id: 'p2',
    province: 'Isabela',
    createdAt: now.subtract(const Duration(hours: 5)),
    author: 'Isabela Riders',
    loopName: 'Saturday club loop',
    caption:
        'Club ride this Saturday. Meetup at 6 AM at the plaza, first '
        'stop at the viewpoint.',
    distanceM: 96000,
    durationS: 11400,
    curviness: 340,
    visibility: LoopVisibility.club,
    likes: 21,
    comments: 8,
  ),
  feedPost(
    id: 'p3',
    province: 'Nueva Vizcaya',
    createdAt: now.subtract(const Duration(days: 1, hours: 2)),
    author: 'Ana Lopez',
    loopName: 'Quick loop',
    stopName: '[Stop name] Viewpoint',
    caption:
        'Hit Shuffle three times and got this one. Never knew this road '
        'existed.',
    photos: const ['#9FB4C4'],
    distanceM: 54000,
    durationS: 4200,
    awayM: 11000,
    likes: 63,
    comments: 17,
  ),
];
