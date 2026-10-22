import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../feed/providers/feed_provider.dart';
import '../../feed/widgets/feed_items.dart';
import '../providers/rider_profile_controller.dart';

/// "Big bike", for the profile's detail line.
String bikeLabel(BikeType bike) => switch (bike) {
  BikeType.scooter => 'Scooter',
  BikeType.underbone => 'Underbone',
  BikeType.bigBike => 'Big bike',
  BikeType.dualSport => 'Dual-sport',
};

/// Another rider: picture, name, town and bike, follow counts, FOLLOW, and
/// their rides and loops. Expects a [RiderProfileController] and a
/// [FeedProvider] for the rider above it.
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

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 1200) _feed.loadMore();
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

  Future<void> _toggleFollow() async {
    final error = await _rider.toggleFollow();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RiderProfileController>();
    final feed = context.watch<FeedProvider>();
    final name = c.rider?.displayName ?? 'A rider';

    final items = <Widget>[
      _Header(
        rider: c.rider,
        loading: c.loading,
        message: c.notFound ? "This rider isn't on Pasyar anymore." : c.error,
        showFollow: !c.isMe,
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.feed),
        onFollow: _toggleFollow,
      ),
      if (!c.notFound)
        ...feedPostItems(
          feed,
          now: widget.clock(),
          actions: feedCardActions(context, feed, clock: widget.clock),
          repo: context.read<FeedRepository>(),
          emptyText: c.isMe
              ? 'Rides you post and loops you share show up here.'
              : "$name hasn't shared any rides you can see yet.",
        ),
    ];

    return Scaffold(
      backgroundColor: PasyarColors.line,
      body: RefreshIndicator(
        color: PasyarColors.accent,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () => Future.wait([c.load(), feed.refresh()]),
        child: ListView.separated(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => items[i],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.rider,
    required this.loading,
    required this.showFollow,
    required this.onBack,
    required this.onFollow,
    this.message,
  });

  final RiderProfile? rider;
  final bool loading;
  final String? message;
  final bool showFollow;
  final VoidCallback onBack;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final rider = this.rider;
    final details = [
      ?rider?.homeArea,
      if (rider?.bikeType case final b?) bikeLabel(b),
    ];
    final bold = const TextStyle(
      fontWeight: FontWeight.w600,
      color: PasyarColors.ink,
    );
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
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: RoundIconButton.ground(
                icon: LucideIcons.chevronLeft,
                semanticLabel: 'Back',
                onPressed: onBack,
              ),
            ),
            const SizedBox(height: 12),
            if (rider == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: PasyarColors.accent,
                        ),
                      )
                    : Text(
                        message ?? '',
                        textAlign: TextAlign.center,
                        style: PasyarTextStyles.body.copyWith(
                          color: PasyarColors.muted,
                        ),
                      ),
              )
            else ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Avatar(
                  name: rider.displayName ?? 'A rider',
                  image: rider.avatarUrl == null
                      ? null
                      : context.read<FeedRepository>().avatar(rider.avatarUrl!),
                  size: 88,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(
                  rider.displayName ?? 'A rider',
                  style: PasyarTextStyles.screenTitle(32),
                ),
              ),
              if (details.isNotEmpty)
                Text(details.join(' · '), style: PasyarTextStyles.label),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${rider.followerCount}', style: bold),
                    TextSpan(
                      text: rider.followerCount == 1
                          ? ' follower · '
                          : ' followers · ',
                    ),
                    TextSpan(text: '${rider.followingCount}', style: bold),
                    const TextSpan(text: ' following'),
                  ],
                ),
                style: PasyarTextStyles.label.copyWith(fontSize: 14),
              ),
              if (showFollow) ...[
                const SizedBox(height: PasyarSpacing.groupGap),
                rider.followedByMe
                    ? SecondaryButton(label: 'FOLLOWING', onPressed: onFollow)
                    : PrimaryButton(
                        label: 'FOLLOW',
                        icon: LucideIcons.userPlus,
                        onPressed: onFollow,
                      ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
