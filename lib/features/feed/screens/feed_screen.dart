import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/app_shell.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../post_a_ride.dart';
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
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  /// Load the next page this close to the end of the list.
  static const _loadAheadPx = 1200.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    tabReselects.addListener(_onTabReselected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The Feed is the first screen after logging in, so it starts
      // location itself ("Near you" waits for the first fix).
      context.read<LocationProvider>().start();
      context.read<FeedProvider>().start();
    });
  }

  @override
  void dispose() {
    tabReselects.removeListener(_onTabReselected);
    _scroll.dispose();
    super.dispose();
  }

  /// Feed tapped while open: back to the top, or new posts when already
  /// there.
  void _onTabReselected() {
    if (tabReselects.branch != feedBranch || !_scroll.hasClients) return;
    if (_scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _refreshKey.currentState?.show();
    }
  }

  void _maybeLoadMore() {
    if (_scroll.position.extentAfter < _loadAheadPx) {
      context.read<FeedProvider>().loadMore();
    }
  }

  /// "Write a post…", then the filter where the post shows: Global, or
  /// My clubs. Text posts never show in "Near you".
  Future<void> _write() async {
    final feed = context.read<FeedProvider>();
    final posted = await context.push<LoopVisibility>(Routes.writePost);
    if (posted == null || !mounted) return;
    final (filter, note) = switch (posted) {
      LoopVisibility.public => (
        FeedFilter.global,
        "Posted. It's under Global.",
      ),
      LoopVisibility.club => (FeedFilter.myClubs, 'Posted to your club.'),
      LoopVisibility.private => (
        null,
        'Posted. Only you can see it, on your profile.',
      ),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(note)));
    if (filter == null) return;
    if (feed.filter == filter) {
      await feed.refresh();
    } else {
      feed.setFilter(filter);
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
      onWrite: _write,
      onAddPhotos: () => postARide(context, clock: widget.clock),
      onSearch: () => _soon('Search'),
      onNotifications: () => _soon('Notifications'),
    );

    final body = _body(feed, now, actions, repo);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: PasyarColors.line,
      body: Stack(
        children: [
          RefreshIndicator(
            key: _refreshKey,
            color: PasyarColors.accent,
            edgeOffset: top,
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
          // Posts scroll under a white status bar, not under the clock.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top,
            child: const ColoredBox(color: PasyarColors.card),
          ),
        ],
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
    final generate = PrimaryButton(
      label: 'GENERATE A LOOP',
      icon: LucideIcons.navigation,
      onPressed: () => context.go(Routes.ride),
    );
    return [
      if (feed.showingGlobalFallback && feed.posts.isNotEmpty)
        const _NothingNearbyNote(),
      ...feedPostItems(
        feed,
        now: now,
        actions: actions,
        repo: repo,
        // "Near you" only ends up empty when Global is empty too.
        emptyText: switch (feed.filter) {
          FeedFilter.nearYou || FeedFilter.global =>
            'No rides on Pasyar yet. Generate a loop, ride it, and post it '
                'to be the first.',
          FeedFilter.following =>
            "Rides from riders you follow show up here. Tap a rider's name on "
                'a post to see their profile and follow them.',
          FeedFilter.myClubs =>
            'Rides and loops from your clubs show up here. Create or join a '
                'club from the Me tab.',
        },
        emptyAction: switch (feed.filter) {
          FeedFilter.nearYou || FeedFilter.global => generate,
          FeedFilter.following => null,
          FeedFilter.myClubs => SecondaryButton(
            label: 'MY CLUBS',
            onPressed: () => context.go(Routes.me),
          ),
        },
      ),
    ];
  }
}

/// Above Global posts shown because "Near you" is empty.
class _NothingNearbyNote extends StatelessWidget {
  const _NothingNearbyNote();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PasyarColors.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PasyarSpacing.screen,
          14,
          PasyarSpacing.screen,
          14,
        ),
        child: Row(
          spacing: 12,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: PasyarColors.accentTint,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Icon(
                  LucideIcons.mapPin,
                  size: 20,
                  color: PasyarColors.accentDark,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No rides near you yet',
                    style: PasyarTextStyles.bodyStrong.copyWith(height: 1.3),
                  ),
                  Text(
                    "Here's what riders are posting elsewhere in the "
                    'Philippines.',
                    style: PasyarTextStyles.label.copyWith(height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
