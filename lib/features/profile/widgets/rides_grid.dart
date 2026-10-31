import 'package:flutter/material.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/post.dart';
import '../../ride/loop_stats.dart';

/// A rider's posts as a 2-column grid of 132 px cards: the first photo (or
/// the loop's shape) with the loop name and km over a dark gradient.
class RidesGrid extends StatelessWidget {
  const RidesGrid({
    super.key,
    required this.posts,
    required this.photo,
    required this.onTap,
  });

  final List<FeedPost> posts;
  final ImageProvider Function(String storagePath) photo;
  final ValueChanged<FeedPost> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 132,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) =>
          _RideCard(post: posts[i], photo: photo, onTap: () => onTap(posts[i])),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({
    required this.post,
    required this.photo,
    required this.onTap,
  });

  final FeedPost post;
  final ImageProvider Function(String storagePath) photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loop = post.loop;
    if (loop == null) return _textCard();
    final first = post.photos.firstOrNull;
    final km = formatDistance(loop.distanceM);
    final white = PasyarTextStyles.body.copyWith(
      color: PasyarColors.card,
      height: 1.2,
    );
    return Semantics(
      button: true,
      label: '${loop.name}, $km',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (first != null)
                Image(
                  image: photo(first.storagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: PasyarColors.ground),
                )
              else
                ColoredBox(
                  color: PasyarColors.mapGround,
                  child: LayoutBuilder(
                    builder: (context, c) => RouteThumbnail(
                      route: loop.sharedRoute ?? const [],
                      width: c.maxWidth,
                      height: c.maxHeight,
                      radius: 0,
                    ),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x0015171C), Color(0xB315171C)],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: white.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(km, style: white.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A text post: its first photo with the words over it, or the words on
  /// `ground`.
  Widget _textCard() {
    final text = (post.caption ?? '').trim();
    final first = post.photos.firstOrNull;
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: first == null
              ? ColoredBox(
                  color: PasyarColors.ground,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      text,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: PasyarTextStyles.bodySmall.copyWith(height: 1.3),
                    ),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image(
                      image: photo(first.storagePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: PasyarColors.ground),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x0015171C), Color(0xB315171C)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 8,
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PasyarTextStyles.body.copyWith(
                          color: PasyarColors.card,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
