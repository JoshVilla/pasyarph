import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/feed_header.dart';
import '../widgets/feed_skeleton.dart';
import '../widgets/post_card.dart';
import 'photo_gallery_screen.dart';

/// The Feed tab (mockup 5): posts from riders near you, newest first, with
/// infinite scroll and pull to refresh.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, this.clock = DateTime.now});

  /// For "2 h ago" (fixed in golden tests).
  final DateTime Function() clock;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();

  /// Load the next page this close to the end of the list.
  static const _loadAheadPx = 1200.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FeedProvider>().start();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.position.extentAfter < _loadAheadPx) {
      context.read<FeedProvider>().loadMore();
    }
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what is coming soon.')));
  }

  Future<void> _like(FeedPost post) async {
    final error = await context.read<FeedProvider>().toggleLike(post.id);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _comments(FeedPost post) async {
    final feed = context.read<FeedProvider>();
    final c = await showCommentsSheet(context, post, clock: widget.clock);
    // Only a full first page tells us the first comment for sure.
    final first = c.comments.isNotEmpty || !c.hasMore
        ? c.firstComment
        : post.firstComment;
    feed.updateComments(post.id, c.count, first);
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    final repo = context.read<FeedRepository>();
    final auth = context.watch<AuthProvider>();
    final now = widget.clock();
    final me = auth.profile?.displayName ?? auth.profile?.fullName ?? 'Me';
    final myAvatar = auth.profile?.avatarUrl;

    final actions = PostCardActions(
      onLike: (post) => _like(post),
      onComment: (post) => _comments(post),
      onShare: (_) => _soon('Sharing'),
      onRide: (_) => _soon('Ride this loop'),
      onMore: (_) => _soon('Reporting and hiding posts'),
      onPhoto: (post, i) => PhotoGalleryScreen.open(context, [
        for (final p in post.photos) repo.photo(p.storagePath),
      ], at: i),
    );

    final header = FeedHeader(
      myName: me,
      myAvatar: myAvatar == null ? null : repo.avatar(myAvatar),
      filter: feed.filter,
      onFilter: feed.setFilter,
      onShare: () => context.go(Routes.create),
      onAddPhotos: () => context.go(Routes.me),
      onSearch: () => _soon('Search'),
      onNotifications: () => _soon('Notifications'),
    );

    final body = _body(feed, now, actions, repo);
    return Scaffold(
      backgroundColor: PasyarColors.line,
      body: RefreshIndicator(
        color: PasyarColors.accent,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: feed.refresh,
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: body.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => i == 0 ? header : body[i - 1],
        ),
      ),
    );
  }

  List<Widget> _body(
    FeedProvider feed,
    DateTime now,
    PostCardActions actions,
    FeedRepository repo,
  ) {
    if (feed.filter == FeedFilter.following) {
      return [
        const _Empty(
          text:
              'Rides from riders you follow will show up here. Following '
              'is coming soon.',
        ),
      ];
    }
    if (feed.filter == FeedFilter.myClubs) {
      return [
        const _Empty(
          text:
              'Rides from your clubs will show up here. Clubs are coming '
              'soon.',
        ),
      ];
    }
    if (feed.needsLocation) {
      return [
        _Empty(
          text: 'Turn on location to see rides near you.',
          action: SecondaryButton(
            label: 'TURN ON LOCATION',
            onPressed: context.read<LocationProvider>().fix,
          ),
        ),
      ];
    }
    if (feed.loading) {
      return const [PostCardSkeleton(), PostCardSkeleton()];
    }
    final posts = feed.posts;
    if (posts.isEmpty) {
      return [
        _Empty(
          text:
              feed.error ??
              'No rides near you yet. Finish a loop and post it to be the '
                  'first.',
        ),
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
        _Empty(text: feed.error!)
      else
        const SizedBox(height: 24),
    ];
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, this.action});

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
