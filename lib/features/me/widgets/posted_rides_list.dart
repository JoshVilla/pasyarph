import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/post.dart';
import '../../ride/loop_stats.dart';

/// Posted rides in a journal: photo or route, date, title and loop details.
class PostedRidesList extends StatelessWidget {
  const PostedRidesList({
    super.key,
    required this.posts,
    required this.photo,
    required this.onTap,
  });

  final List<FeedPost> posts;
  final ImageProvider Function(String storagePath) photo;
  final ValueChanged<FeedPost> onTap;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Ride journal',
              style: PasyarTextStyles.of(
                context,
              ).bodyLarge.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${posts.length} ${posts.length == 1 ? 'post' : 'posts'}',
            style: PasyarTextStyles.of(context).label,
          ),
        ],
      ),
      for (final post in posts)
        _PostedRideCard(post: post, photo: photo, onTap: () => onTap(post)),
    ],
  );
}

class _PostedRideCard extends StatelessWidget {
  const _PostedRideCard({
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
    final caption = post.caption?.trim() ?? '';
    final title = loop?.name ?? (caption.isEmpty ? 'Ride update' : caption);
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(post.createdAt.toLocal());
    final km = loop == null ? null : formatDistance(loop.distanceM);
    return Semantics(
      button: true,
      label: [title, ?km, date].join(', '),
      excludeSemantics: true,
      child: Material(
        color: PasyarColors.of(context).card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: PasyarColors.of(context).line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    _thumbnail(context),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 5,
                        children: [
                          Text(date, style: PasyarTextStyles.of(context).label),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: PasyarTextStyles.of(context).bodyLarge,
                          ),
                          if (loop != null && caption.isNotEmpty)
                            Text(
                              caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PasyarTextStyles.of(context).label,
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        LucideIcons.arrowUpRight,
                        size: 18,
                        color: PasyarColors.of(context).muted,
                      ),
                    ),
                  ],
                ),
                if (loop != null) ...[
                  Divider(height: 1, color: PasyarColors.of(context).line),
                  Wrap(
                    spacing: 18,
                    runSpacing: 8,
                    children: [
                      _detail(context, LucideIcons.route, km!),
                      _detail(
                        context,
                        LucideIcons.clock,
                        formatRideTime(loop.durationS),
                      ),
                      if (post.photos.isNotEmpty)
                        _detail(
                          context,
                          LucideIcons.images,
                          '${post.photos.length} ${post.photos.length == 1 ? 'photo' : 'photos'}',
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(BuildContext context, IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      Icon(icon, size: 15, color: PasyarColors.of(context).muted),
      Text(label, style: PasyarTextStyles.of(context).bodySmall),
    ],
  );

  Widget _thumbnail(BuildContext context) {
    final first = post.photos.firstOrNull;
    final route = post.loop?.sharedRoute;
    final fallback = route != null && route.length > 1
        ? RouteThumbnail(route: route, width: 76, height: 76, radius: 0)
        : ColoredBox(
            color: PasyarColors.of(context).accentTint,
            child: Center(
              child: Icon(
                LucideIcons.notebookPen,
                color: PasyarColors.of(context).accent,
                size: 26,
              ),
            ),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 76,
        height: 76,
        child: first == null
            ? fallback
            : Image(
                image: photo(first.storagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
