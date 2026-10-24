import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../clubs/widgets/my_clubs_list.dart';
import '../../riders/screens/rider_profile_screen.dart' show bikeLabel;
import '../me_rules.dart';
import '../providers/me_controller.dart';
import '../widgets/my_loops_list.dart';
import '../widgets/posts_grid.dart';
import '../widgets/ride_history_list.dart';
import '../widgets/saved_loops_list.dart';

enum MeTab { posts, loops, saved }

/// The Me tab: picture, name and totals (km ridden, loops ridden, posts),
/// EDIT PROFILE and Settings, then Posts (rides to post and a photo grid),
/// My loops (with clubs) and Saved loops. Expects a [MeController] above it.
class MeScreen extends StatefulWidget {
  const MeScreen({super.key, this.initialTab = MeTab.posts});

  final MeTab initialTab;

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

  @override
  Widget build(BuildContext context) {
    final me = context.watch<MeController>();
    final top = MediaQuery.paddingOf(context).top;
    final sections = <Widget>[
      _Header(totals: me),
      ColoredBox(
        color: PasyarColors.card,
        child: Padding(
          padding: const EdgeInsets.all(PasyarSpacing.screen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: PasyarSpacing.groupGap,
            children: [
              SegmentedChoice<MeTab>(
                semanticLabel: 'Show',
                options: const {
                  MeTab.posts: 'Posts',
                  MeTab.loops: 'My loops',
                  MeTab.saved: 'Saved',
                },
                selected: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
              ...switch (_tab) {
                MeTab.posts => _posts(me),
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
      backgroundColor: PasyarColors.line,
      body: RefreshIndicator(
        color: PasyarColors.accent,
        edgeOffset: top,
        onRefresh: me.load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: sections.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => sections[i],
        ),
      ),
    );
  }

  List<Widget> _posts(MeController me) {
    final posts = me.posts;
    final empty = PasyarTextStyles.body.copyWith(color: PasyarColors.muted);
    return [
      const RideHistoryList(),
      Text('YOUR POSTS', style: PasyarTextStyles.screenTitle(24)),
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
        PostsGrid(
          posts: posts,
          photo: context.read<FeedRepository>().photo,
          onTap: (p) => context.push(Routes.postLink(p.id)),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.totals});

  final MeController totals;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final name = profile?.displayName ?? profile?.fullName ?? 'Rider';
    final details = [
      ?profile?.homeArea,
      if (profile?.bikeType case final b?) bikeLabel(b),
    ];
    final t = totals.totals;
    final top = MediaQuery.paddingOf(context).top;

    return ColoredBox(
      color: PasyarColors.card,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PasyarSpacing.screen,
          top + 8,
          PasyarSpacing.screen,
          PasyarSpacing.sheet,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(
                  name: name,
                  image: profile?.avatarUrl == null
                      ? null
                      : context.read<FeedRepository>().avatar(
                          profile!.avatarUrl!,
                        ),
                  size: 88,
                ),
                const Spacer(),
                RoundIconButton.ground(
                  icon: LucideIcons.settings,
                  semanticLabel: 'Settings',
                  onPressed: () => context.push(Routes.settings),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(name, style: PasyarTextStyles.screenTitle(32)),
            ),
            if (details.isNotEmpty)
              Text(details.join(' · '), style: PasyarTextStyles.label),
            const SizedBox(height: 16),
            StatRow(
              children: [
                StatBlock(label: 'KM ridden', value: formatTotalKm(t.riddenM)),
                StatBlock(label: 'Loops ridden', value: '${t.loopsRidden}'),
                StatBlock(label: 'Posts', value: '${t.posts}'),
              ],
            ),
            const SizedBox(height: PasyarSpacing.groupGap),
            SecondaryButton(
              label: 'EDIT PROFILE',
              icon: LucideIcons.userPen,
              onPressed: () => context.push(Routes.editProfile),
            ),
          ],
        ),
      ),
    );
  }
}
