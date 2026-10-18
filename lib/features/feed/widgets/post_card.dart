import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/map/pasyar_map.dart';
import '../../../core/map/route_style.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/post.dart';
import '../../ride/loop_stats.dart';
import '../feed_format.dart';
import 'photo_collage.dart';

/// What a card's buttons do; the feed screen supplies these.
class PostCardActions {
  const PostCardActions({
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onRide,
    required this.onMore,
    required this.onPhoto,
  });

  final ValueChanged<FeedPost> onLike;
  final ValueChanged<FeedPost> onComment;
  final ValueChanged<FeedPost> onShare;
  final ValueChanged<FeedPost> onRide;
  final ValueChanged<FeedPost> onMore;

  /// Photo [int] of the post was tapped.
  final void Function(FeedPost post, int index) onPhoto;
}

/// One post in the feed (mockup 5). With photos it's a ride post: caption,
/// collage, loop card with RIDE IT. Without, it's a shared loop: a big map
/// with stat chips and RIDE THIS LOOP.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.now,
    required this.actions,
    required this.photo,
    required this.avatar,
  });

  final FeedPost post;
  final DateTime now;
  final PostCardActions actions;

  /// Image for a photo's storage path / an avatar URL.
  final ImageProvider Function(String storagePath) photo;
  final ImageProvider Function(String url) avatar;

  bool get _isRide => post.photos.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final caption = post.caption;
    final comment = post.firstComment;
    return ColoredBox(
      color: PasyarColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(post: post, now: now, avatar: avatar, onMore: actions.onMore),
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(caption, style: PasyarTextStyles.body),
            ),
          if (_isRide) ...[
            PhotoCollage(
              photos: [for (final p in post.photos) photo(p.storagePath)],
              onTap: (i) => actions.onPhoto(post, i),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _LoopCard(post: post, onRide: () => actions.onRide(post)),
            ),
          ] else ...[
            _LoopMap(post: post),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _RideThisLoopButton(onPressed: () => actions.onRide(post)),
            ),
          ],
          _Counts(post: post),
          _ActionRow(post: post, actions: actions, lineBelow: comment != null),
          if (comment != null)
            _CommentPreview(
              comment: comment,
              total: post.commentCount,
              avatar: avatar,
              onViewAll: () => actions.onComment(post),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.post,
    required this.now,
    required this.avatar,
    required this.onMore,
  });

  final FeedPost post;
  final DateTime now;
  final ImageProvider Function(String url) avatar;
  final ValueChanged<FeedPost> onMore;

  @override
  Widget build(BuildContext context) {
    final name = post.author.displayName ?? 'A rider';
    final url = post.author.avatarUrl;
    final bold = const TextStyle(fontWeight: FontWeight.w600);
    final meta = [
      timeAgo(post.createdAt, now),
      ?stopLabel(post.loop.mainStop),
      visibilityLabel(post.loop.visibility),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 10),
      child: Row(
        spacing: 10,
        children: [
          Avatar(name: name, image: url == null ? null : avatar(url)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: post.photos.isNotEmpty
                        ? [
                            TextSpan(text: name, style: bold),
                            const TextSpan(text: ' rode '),
                            TextSpan(text: post.loop.name, style: bold),
                          ]
                        : [
                            TextSpan(text: name, style: bold),
                            const TextSpan(text: ' shared a new loop'),
                          ],
                  ),
                  style: PasyarTextStyles.body.copyWith(height: 1.3),
                ),
                Text(meta, style: PasyarTextStyles.label.copyWith(height: 1.2)),
              ],
            ),
          ),
          SizedBox.square(
            dimension: PasyarSpacing.minTouch,
            child: IconButton(
              tooltip: 'More options',
              onPressed: () => onMore(post),
              icon: const Icon(
                LucideIcons.ellipsis,
                size: 20,
                color: PasyarColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `ground` card: route thumbnail, name, stats and distance, RIDE IT.
class _LoopCard extends StatelessWidget {
  const _LoopCard({required this.post, required this.onRide});

  final FeedPost post;
  final VoidCallback onRide;

  @override
  Widget build(BuildContext context) {
    final loop = post.loop;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: PasyarColors.ground,
        borderRadius: BorderRadius.circular(PasyarRadius.choiceCard),
      ),
      child: Row(
        spacing: 12,
        children: [
          RouteThumbnail(
            route: loop.sharedRoute ?? const [],
            width: 64,
            height: 50,
            radius: 8,
            startColor: PasyarColors.ink,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loop.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PasyarTextStyles.bodyStrong.copyWith(height: 1.2),
                ),
                // With a province: "118 km · 3 h 50" then "Ifugao · 6 km
                // from you" (three lines still fit beside the thumbnail).
                if (loop.province case final province?) ...[
                  Text(
                    loopStats(loop),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PasyarTextStyles.label.copyWith(height: 1.2),
                  ),
                  Text(
                    '$province · ${distanceFromYou(post.distanceAwayM)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PasyarTextStyles.label.copyWith(height: 1.2),
                  ),
                ] else
                  Text(
                    '${loopStats(loop)} · ${distanceFromYou(post.distanceAwayM)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PasyarTextStyles.label.copyWith(height: 1.2),
                  ),
              ],
            ),
          ),
          _SmallButton(label: 'RIDE IT', onPressed: onRide),
        ],
      ),
    );
  }
}

/// 40 px orange button with a 44 px touch area (RIDE IT).
class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // The row is 50 px tall (the thumbnail), so the 44 px touch area fits.
    return SizedBox(
      height: PasyarSpacing.minTouch,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox(
            height: PasyarSpacing.minTouch,
            child: Center(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PasyarColors.accent,
                  borderRadius: BorderRadius.circular(PasyarRadius.input),
                ),
                child: Text(
                  label,
                  style: PasyarTextStyles.buttonPrimary.copyWith(
                    color: PasyarColors.card,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared loop: the trimmed route on a real map, with stat chips.
class _LoopMap extends StatelessWidget {
  const _LoopMap({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final loop = post.loop;
    final route = loop.sharedRoute ?? const <LatLng>[];
    final stop = loop.mainStop?.location;
    final curvy = loop.curvinessScore;
    return SizedBox(
      height: 230,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: route.length > 1
                      ? CameraFit.coordinates(
                          coordinates: route,
                          padding: const EdgeInsets.fromLTRB(40, 30, 40, 60),
                        )
                      : null,
                  initialCenter: route.isEmpty
                      ? const LatLng(16.67, 121.45)
                      : route.first,
                  backgroundColor: PasyarColors.mapGround,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  ?pasyarTileLayer(),
                  PolylineLayer(polylines: routePolylines(route: route)),
                  CircleLayer(
                    circles: [
                      if (route.isNotEmpty)
                        CircleMarker(
                          point: route.first,
                          radius: 10,
                          color: PasyarColors.ink,
                          borderColor: PasyarColors.card,
                          borderStrokeWidth: 3,
                        ),
                      if (stop != null)
                        CircleMarker(
                          point: stop,
                          radius: 12,
                          color: PasyarColors.accent,
                          borderColor: PasyarColors.card,
                          borderStrokeWidth: 3,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            // Wraps upward if a long province name won't fit on one row.
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (loop.province case final province?) _Chip(province),
                _Chip(formatDistance(loop.distanceM)),
                _Chip(formatRideTime(loop.durationS)),
                if (curvy != null) _Chip('Curvy: ${curvyLevel(curvy).label}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const ShapeDecoration(
        color: PasyarColors.card,
        shape: StadiumBorder(),
      ),
      // widthFactor 1: as wide as the text, not the whole row.
      child: Align(
        widthFactor: 1,
        child: Text(
          text,
          style: PasyarTextStyles.label.copyWith(
            height: 1,
            fontWeight: FontWeight.w600,
            color: PasyarColors.ink,
          ),
        ),
      ),
    );
  }
}

/// 48 px RIDE THIS LOOP (shared loop posts).
class _RideThisLoopButton extends StatelessWidget {
  const _RideThisLoopButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PasyarColors.accent,
      borderRadius: BorderRadius.circular(PasyarRadius.choiceCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              'RIDE THIS LOOP',
              style: PasyarTextStyles.buttonPrimary.copyWith(
                color: PasyarColors.card,
                fontSize: 19,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "48 likes" and "12 comments".
class _Counts extends StatelessWidget {
  const _Counts({required this.post});

  final FeedPost post;

  @override
  Widget build(BuildContext context) {
    final style = PasyarTextStyles.label.copyWith(height: 1.2);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(plural(post.likeCount, 'like'), style: style),
          Text(plural(post.commentCount, 'comment'), style: style),
        ],
      ),
    );
  }
}

/// Like / Comment / Share, between 1 px `line` rules.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.post,
    required this.actions,
    required this.lineBelow,
  });

  final FeedPost post;
  final PostCardActions actions;
  final bool lineBelow;

  @override
  Widget build(BuildContext context) {
    const rule = BorderSide(color: PasyarColors.line);
    final liked = post.likedByMe;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(top: rule, bottom: lineBelow ? rule : BorderSide.none),
      ),
      child: Row(
        children: [
          _Action(
            icon: LucideIcons.heart,
            label: liked ? 'Liked' : 'Like',
            filled: liked,
            onTap: () => actions.onLike(post),
          ),
          _Action(
            icon: LucideIcons.messageSquare,
            label: 'Comment',
            onTap: () => actions.onComment(post),
          ),
          _Action(
            icon: LucideIcons.forward,
            label: 'Share',
            onTap: () => actions.onShare(post),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = filled ? PasyarColors.accentDark : PasyarColors.ink;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 6,
            children: [
              filled
                  ? const Icon(
                      Icons.favorite,
                      size: 20,
                      color: PasyarColors.accent,
                    )
                  : Icon(icon, size: 20, color: color),
              Text(
                label,
                style: PasyarTextStyles.bodySmall.copyWith(
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The first comment in a `ground` bubble, and "View all N comments".
class _CommentPreview extends StatelessWidget {
  const _CommentPreview({
    required this.comment,
    required this.total,
    required this.avatar,
    required this.onViewAll,
  });

  final FeedComment comment;
  final int total;
  final ImageProvider Function(String url) avatar;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final name = comment.author.displayName ?? 'A rider';
    final url = comment.author.avatarUrl;
    final text = PasyarTextStyles.bodySmall.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.35,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Avatar(
                name: name,
                size: 32,
                image: url == null ? null : avatar(url),
              ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: PasyarColors.ground,
                    borderRadius: BorderRadius.circular(
                      PasyarRadius.choiceCard,
                    ),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$name\n',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: comment.body),
                      ],
                    ),
                    style: text,
                  ),
                ),
              ),
            ],
          ),
          if (total > 1)
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: GestureDetector(
                onTap: onViewAll,
                child: Text(
                  'View all $total comments',
                  style: PasyarTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PasyarColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
