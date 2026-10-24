import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/post.dart';

/// The rider's posts as a 3-column grid of square first photos (or the
/// loop's shape when a post has none). A stack icon marks posts with more
/// than one photo.
class PostsGrid extends StatelessWidget {
  const PostsGrid({
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
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];
        final first = post.photos.firstOrNull;
        return Semantics(
          button: true,
          label: switch (post.photos.length) {
            0 => '${post.loop.name}, no photos',
            1 => '${post.loop.name}, 1 photo',
            final n => '${post.loop.name}, $n photos',
          },
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => onTap(post),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PasyarRadius.photoSlot),
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
                          route: post.loop.sharedRoute ?? const [],
                          width: c.maxWidth,
                          height: c.maxHeight,
                          radius: 0,
                        ),
                      ),
                    ),
                  if (post.photos.length > 1)
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        LucideIcons.images,
                        size: 18,
                        color: PasyarColors.card,
                        shadows: [
                          Shadow(color: Color(0x6615171C), blurRadius: 4),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
