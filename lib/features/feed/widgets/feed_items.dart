import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../ride/ride_this_loop.dart';
import '../providers/feed_provider.dart';
import '../screens/photo_gallery_screen.dart';
import 'comments_sheet.dart';
import 'feed_skeleton.dart';
import 'post_card.dart';

/// What post cards do, for posts loaded by [feed]: like, comments, RIDE IT,
/// photos, and the author's profile. Used by the Feed tab, club pages and
/// rider profiles.
PostCardActions feedCardActions(
  BuildContext context,
  FeedProvider feed, {
  required DateTime Function() clock,
}) {
  void snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  final repo = context.read<FeedRepository>();
  return PostCardActions(
    onLike: (post) async {
      final error = await feed.toggleLike(post.id);
      if (error != null && context.mounted) snack(error);
    },
    onComment: (post) async {
      final c = await showCommentsSheet(context, post, clock: clock);
      // Only a full first page tells us the first comment for sure.
      final first = c.comments.isNotEmpty || !c.hasMore
          ? c.firstComment
          : post.firstComment;
      feed.updateComments(post.id, c.count, first);
      c.dispose();
    },
    onShare: (_) => snack('Sharing is coming soon.'),
    onRide: (post) =>
        rideThisLoop(context, loopId: post.loop.id, name: post.loop.name),
    onMore: (_) => snack('Reporting and hiding posts is coming soon.'),
    onPhoto: (post, i) => PhotoGalleryScreen.open(context, [
      for (final p in post.photos) repo.photo(p.storagePath),
    ], at: i),
    onAuthor: (post) => context.push(Routes.rider(post.author.id)),
  );
}

/// The cards of [feed] as list items: skeletons while the first page
/// loads, [emptyText] and [emptyAction] (or the error) when there's
/// nothing, then the posts and a spinner while the next page loads.
List<Widget> feedPostItems(
  FeedProvider feed, {
  required DateTime now,
  required PostCardActions actions,
  required FeedRepository repo,
  required String emptyText,
  Widget? emptyAction,
}) {
  if (feed.loading) {
    return const [PostCardSkeleton(), PostCardSkeleton()];
  }
  final posts = feed.posts;
  if (posts.isEmpty) {
    final error = feed.error;
    return [
      error != null
          ? FeedEmpty(text: error)
          : FeedEmpty(text: emptyText, action: emptyAction),
    ];
  }
  return [
    for (final FeedPost p in posts)
      PostCard(
        key: ValueKey(p.id),
        post: p,
        now: now,
        actions: actions,
        photo: repo.photo,
        avatar: repo.avatar,
      ),
    if (feed.loadingMore)
      const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: PasyarColors.accent),
        ),
      )
    else if (feed.error != null)
      FeedEmpty(text: feed.error!)
    else
      const SizedBox(height: 24),
  ];
}

/// A white band with muted, centered text and an optional button.
class FeedEmpty extends StatelessWidget {
  const FeedEmpty({super.key, required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PasyarColors.card,
      child: Padding(
        padding: const EdgeInsets.all(PasyarSpacing.sheet),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: PasyarSpacing.groupGap,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: PasyarTextStyles.body.copyWith(color: PasyarColors.muted),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
