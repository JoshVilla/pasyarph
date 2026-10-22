import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/feed_provider.dart';
import '../widgets/feed_header.dart';
import '../widgets/feed_items.dart';
import '../widgets/post_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();
    final repo = context.read<FeedRepository>();
    final auth = context.watch<AuthProvider>();
    final now = widget.clock();
    final me = auth.profile?.displayName ?? auth.profile?.fullName ?? 'Me';
    final myAvatar = auth.profile?.avatarUrl;

    final actions = feedCardActions(context, feed, clock: widget.clock);

    final header = FeedHeader(
      myName: me,
      myAvatar: myAvatar == null ? null : repo.avatar(myAvatar),
      filter: feed.filter,
      onFilter: feed.setFilter,
      onShare: () => context.push(Routes.create),
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
    if (feed.needsLocation) {
      return [
        FeedEmpty(
          text: 'Turn on location to see rides near you.',
          action: SecondaryButton(
            label: 'TURN ON LOCATION',
            onPressed: context.read<LocationProvider>().fix,
          ),
        ),
      ];
    }
    return feedPostItems(
      feed,
      now: now,
      actions: actions,
      repo: repo,
      emptyText: switch (feed.filter) {
        FeedFilter.nearYou =>
          'No rides near you yet. Finish a loop and post it to be the first.',
        FeedFilter.following =>
          "Rides from riders you follow show up here. Tap a rider's name on "
              'a post to see their profile and follow them.',
        FeedFilter.myClubs =>
          'Rides and loops from your clubs show up here. Create or join a '
              'club from the Me tab.',
      },
      emptyAction: feed.filter == FeedFilter.myClubs
          ? SecondaryButton(
              label: 'MY CLUBS',
              onPressed: () => context.go(Routes.me),
            )
          : null,
    );
  }
}
