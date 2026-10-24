import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/links.dart';
import '../../../core/router.dart';
import '../../../core/share.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/loop.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/loop_repository.dart';
import '../../feed/providers/feed_provider.dart';
import '../../me/widgets/loop_row.dart';
import '../../moderation/widgets/report_sheet.dart';
import '../../profile/widgets/profile_cover.dart';
import '../../profile/widgets/profile_header.dart';
import '../../profile/widgets/rides_grid.dart';
import '../../ride/ride_this_loop.dart';
import '../providers/rider_profile_controller.dart';

enum _RiderAction { report, block }

enum RiderTab { rides, loops }

/// Another rider's profile: their cover, picture, name, @username, bio,
/// follower counts and stats, FOLLOW / FOLLOWING, then their Rides and
/// Loops. Share and ⋯ (report, block) on the banner. Expects a
/// [RiderProfileController] and a [FeedProvider] for the rider above it.
class RiderProfileScreen extends StatefulWidget {
  const RiderProfileScreen({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _scroll = ScrollController();
  late final RiderProfileController _rider = context
      .read<RiderProfileController>();
  late final FeedProvider _feed = context.read<FeedProvider>();
  RiderTab _tab = RiderTab.rides;
  List<Loop>? _loops;
  String? _loopsError;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_tab == RiderTab.rides && _scroll.position.extentAfter < 1200) {
        _feed.loadMore();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rider.load();
      _feed.start();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadLoops() async {
    try {
      final loops = await context.read<LoopRepository>().ofRider(_rider.userId);
      if (!mounted) return;
      setState(() {
        _loops = loops;
        _loopsError = null;
      });
    } on LoopException catch (e) {
      if (mounted) setState(() => _loopsError = e.message);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggleFollow() async {
    final error = await _rider.toggleFollow();
    if (error != null && mounted) _snack(error);
  }

  Future<void> _unblock() async {
    final error = await _rider.unblock();
    if (!mounted) return;
    if (error != null) return _snack(error);
    await _feed.refresh();
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.feed);

  Future<void> _more(String name) async {
    final action = await showActionSheet<_RiderAction>(
      context,
      title: name,
      actions: [
        const SheetAction(
          value: _RiderAction.report,
          label: 'Report rider',
          icon: LucideIcons.flag,
        ),
        if (!_rider.blocked)
          SheetAction(
            value: _RiderAction.block,
            label: 'Block $name',
            icon: LucideIcons.ban,
            destructive: true,
          ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _RiderAction.report:
        final result = await showReportSheet(
          context,
          ReportSubject(
            target: ReportTarget.user,
            id: _rider.userId,
            what: 'rider',
            authorId: _rider.blocked ? null : _rider.userId,
            authorName: name,
          ),
        );
        if (result == null || !mounted) return;
        _snack('Thanks for reporting. A moderator will take a look.');
        if (result.blocked) await _rider.markBlocked();
      case _RiderAction.block:
        final blocked = await confirmBlock(
          context,
          userId: _rider.userId,
          name: name,
        );
        if (blocked && mounted) await _rider.markBlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RiderProfileController>();
    final feed = context.watch<FeedProvider>();
    final repo = context.read<FeedRepository>();
    final rider = c.rider;
    final name = rider?.displayName ?? 'A rider';
    final back = CoverIconButton(
      icon: LucideIcons.chevronLeft,
      label: 'Back',
      onPressed: _back,
    );
    final muted = PasyarTextStyles.body.copyWith(color: PasyarColors.muted);

    if (rider == null) {
      return Scaffold(
        backgroundColor: PasyarColors.card,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            ProfileCover(leading: back),
            Padding(
              padding: const EdgeInsets.all(32),
              child: c.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: PasyarColors.accent,
                      ),
                    )
                  : Text(
                      c.notFound
                          ? "This rider isn't on Pasyar anymore."
                          : c.error ?? '',
                      textAlign: TextAlign.center,
                      style: muted,
                    ),
            ),
          ],
        ),
      );
    }

    final header = ProfileHeader(
      data: ProfileHeaderData(
        name: name,
        username: rider.username,
        bio: rider.bio,
        bike: rider.bikeType,
        homeArea: rider.homeArea,
        avatar: rider.avatarUrl == null ? null : repo.avatar(rider.avatarUrl!),
        cover: rider.coverUrl == null ? null : repo.avatar(rider.coverUrl!),
        followers: rider.followerCount,
        following: rider.followingCount,
        riddenM: rider.riddenM,
        loopsRidden: rider.loopsRidden,
        posts: rider.posts,
      ),
      action: c.isMe
          ? ProfilePillButton(
              label: 'Edit profile',
              onPressed: () => context.push(Routes.editProfile),
            )
          : c.blocked
          ? ProfilePillButton(
              label: 'Unblock',
              outlined: true,
              onPressed: _unblock,
            )
          : rider.followedByMe
          ? ProfilePillButton(
              label: 'Following',
              outlined: true,
              onPressed: _toggleFollow,
            )
          : ProfilePillButton(label: 'Follow', onPressed: _toggleFollow),
      coverLeading: back,
      coverActions: [
        CoverIconButton(
          icon: LucideIcons.share2,
          label: 'Share profile',
          onPressed: () => context.read<Sharer>().share(
            riderShareMessage(
              name: name,
              username: rider.username,
              link: AppLinks.rider(rider.id),
            ),
            subject: name,
          ),
        ),
        if (!c.isMe)
          CoverIconButton(
            icon: LucideIcons.ellipsis,
            label: 'More',
            onPressed: () => _more(name),
          ),
      ],
      onFollowers: () => context.push(Routes.followers(rider.id)),
      onFollowing: () => context.push(Routes.following(rider.id)),
    );

    final List<Widget> content;
    if (c.blocked) {
      content = [
        Text(
          "You blocked $name. You won't see their rides, loops or comments.",
          style: muted,
        ),
      ];
    } else {
      content = [
        ProfileTabs<RiderTab>(
          tabs: const {RiderTab.rides: 'Rides', RiderTab.loops: 'Loops'},
          selected: _tab,
          onChanged: (t) {
            setState(() => _tab = t);
            if (t == RiderTab.loops && _loops == null) _loadLoops();
          },
        ),
        ...switch (_tab) {
          RiderTab.rides => _rides(feed, repo, name, muted),
          RiderTab.loops => _loopList(name, muted),
        },
      ];
    }

    return Scaffold(
      backgroundColor: PasyarColors.card,
      body: RefreshIndicator(
        color: PasyarColors.accent,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () => Future.wait([
          c.load(),
          feed.refresh(),
          if (_loops != null) _loadLoops(),
        ]),
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            header,
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PasyarSpacing.screen,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rides(
    FeedProvider feed,
    FeedRepository repo,
    String name,
    TextStyle muted,
  ) {
    if (feed.loading) {
      return const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(color: PasyarColors.accent),
          ),
        ),
      ];
    }
    final posts = [
      for (final p in feed.posts)
        if (!p.isLoopOnly) p,
    ];
    if (posts.isEmpty) {
      return [
        Text(
          feed.error ?? "$name hasn't posted any rides you can see yet.",
          style: muted,
        ),
      ];
    }
    return [
      RidesGrid(
        posts: posts,
        photo: repo.photo,
        onTap: (p) => context.push(Routes.postLink(p.id)),
      ),
      if (feed.loadingMore)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: CircularProgressIndicator(color: PasyarColors.accent),
          ),
        ),
    ];
  }

  List<Widget> _loopList(String name, TextStyle muted) {
    final loops = _loops;
    if (loops == null) {
      return [
        if (_loopsError != null)
          Text(_loopsError!, style: muted)
        else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(color: PasyarColors.accent),
            ),
          ),
      ];
    }
    if (loops.isEmpty) {
      return [
        Text("$name hasn't shared any loops you can see yet.", style: muted),
      ];
    }
    return [
      for (final loop in loops)
        LoopRow(
          loop: loop,
          detail: loop.province,
          onTap: () => rideThisLoop(context, loopId: loop.id, name: loop.name),
        ),
    ];
  }
}
