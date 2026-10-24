import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/links.dart';
import '../../../core/router.dart';
import '../../../core/share.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../clubs/widgets/my_clubs_list.dart';
import '../../profile/edit_cover.dart';
import '../../profile/providers/cover_controller.dart';
import '../../profile/widgets/profile_cover.dart';
import '../../profile/widgets/profile_header.dart';
import '../../profile/widgets/rides_grid.dart';
import '../providers/me_controller.dart';
import '../widgets/my_loops_list.dart';
import '../widgets/ride_history_list.dart';
import '../widgets/saved_loops_list.dart';

enum MeTab { rides, loops, saved }

/// The Me tab: cover banner (Edit cover), picture, name, @username, bio,
/// follower counts and stat tiles, then Rides (a grid of posts, and the
/// rides still to post), My loops (with clubs) and Saved. Expects a
/// [MeController] above it.
class MeScreen extends StatefulWidget {
  const MeScreen({super.key, this.initialTab = MeTab.rides, this.pick});

  final MeTab initialTab;

  /// Replaceable in tests (the cover picker).
  final PickPhoto? pick;

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  late MeTab _tab = widget.initialTab;
  late final MeController _me = context.read<MeController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _me.load());
  }

  void _share(String userId, String name, String? username) =>
      context.read<Sharer>().share(
        riderShareMessage(
          name: name,
          username: username,
          link: AppLinks.rider(userId),
        ),
        subject: name,
      );

  @override
  Widget build(BuildContext context) {
    final me = context.watch<MeController>();
    final auth = context.watch<AuthProvider>();
    final covers = context.watch<CoverController>();
    final feed = context.read<FeedRepository>();
    final profile = auth.profile;
    final userId = auth.user?.id ?? '';
    final name = profile?.displayName ?? profile?.fullName ?? 'Rider';
    final t = me.totals;

    void editProfile() => context.push(Routes.editProfile);

    final header = ProfileHeader(
      data: ProfileHeaderData(
        name: name,
        username: profile?.username,
        bio: profile?.bio,
        bike: profile?.bikeType,
        homeArea: profile?.homeArea,
        avatar: profile?.avatarUrl == null
            ? null
            : feed.avatar(profile!.avatarUrl!),
        cover: covers.coverUrl == null ? null : feed.avatar(covers.coverUrl!),
        followers: me.followers,
        following: me.following,
        riddenM: t.riddenM,
        loopsRidden: t.loopsRidden,
        posts: t.posts,
      ),
      action: ProfilePillButton(label: 'Edit profile', onPressed: editProfile),
      coverActions: [
        CoverIconButton(
          icon: LucideIcons.share2,
          label: 'Share profile',
          onPressed: () => _share(userId, name, profile?.username),
        ),
        CoverIconButton(
          icon: LucideIcons.settings,
          label: 'Settings',
          onPressed: () => context.push(Routes.settings),
        ),
      ],
      onEditCover: () => widget.pick == null
          ? editCover(context)
          : editCover(context, pick: widget.pick!),
      coverBusy: covers.busy,
      onFollowers: () => context.push(Routes.followers(userId)),
      onFollowing: () => context.push(Routes.following(userId)),
      onAddUsername: editProfile,
    );

    final sections = <Widget>[
      header,
      ColoredBox(
        color: PasyarColors.card,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PasyarSpacing.screen,
            0,
            PasyarSpacing.screen,
            PasyarSpacing.sheet,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              ProfileTabs<MeTab>(
                tabs: const {
                  MeTab.rides: 'Rides',
                  MeTab.loops: 'My loops',
                  MeTab.saved: 'Saved',
                },
                selected: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
              ...switch (_tab) {
                MeTab.rides => _rides(me, feed),
                MeTab.loops => const [
                  MyLoopsList(),
                  SizedBox(height: 16),
                  MyClubsList(),
                ],
                MeTab.saved => const [SavedLoopsList()],
              },
            ],
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: PasyarColors.card,
      body: RefreshIndicator(
        color: PasyarColors.accent,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () => Future.wait([me.load(), auth.reloadProfile()]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: sections,
        ),
      ),
    );
  }

  List<Widget> _rides(MeController me, FeedRepository feed) {
    final posts = me.posts;
    final empty = PasyarTextStyles.body.copyWith(color: PasyarColors.muted);
    return [
      if (posts == null)
        me.error != null
            ? Text(me.error!, style: empty)
            : const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: PasyarColors.accent),
                ),
              )
      else if (posts.isEmpty)
        Text('Ride a loop, then post it with your photos.', style: empty)
      else
        RidesGrid(
          posts: posts,
          photo: feed.photo,
          onTap: (p) => context.push(Routes.postLink(p.id)),
        ),
      const SizedBox(height: 8),
      // Rides still to post (and deleting rides) live here too.
      const RideHistoryList(),
    ];
  }
}
