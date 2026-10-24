import 'package:flutter/material.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/enums.dart';
import '../../me/me_rules.dart' show formatTotalKm;
import '../../me/profile_rules.dart';
import 'profile_cover.dart';

/// What a profile header shows, for the rider's own profile or another's.
class ProfileHeaderData {
  const ProfileHeaderData({
    required this.name,
    this.username,
    this.bio,
    this.bike,
    this.homeArea,
    this.avatar,
    this.cover,
    this.followers = 0,
    this.following = 0,
    this.riddenM = 0,
    this.loopsRidden = 0,
    this.posts = 0,
  });

  final String name;
  final String? username;
  final String? bio;
  final BikeType? bike;
  final String? homeArea;
  final ImageProvider? avatar;
  final ImageProvider? cover;
  final int followers;
  final int following;
  final int riddenM;
  final int loopsRidden;
  final int posts;
}

/// Avatar overlap onto the banner.
const _overlap = 40.0;
const _avatarSize = 84.0;

/// Cover banner, avatar row with [action] (Edit profile or Follow), name,
/// @username · bike · town, bio, follower counts, and stat tiles.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.data,
    required this.action,
    this.coverLeading,
    this.coverActions = const [],
    this.onEditCover,
    this.coverBusy = false,
    this.onFollowers,
    this.onFollowing,
    this.onAddUsername,
  });

  final ProfileHeaderData data;

  /// Right of the avatar: Edit profile, or Follow / Following.
  final Widget action;
  final Widget? coverLeading;
  final List<Widget> coverActions;
  final VoidCallback? onEditCover;
  final bool coverBusy;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  /// Own profile without a username: "Add a username" instead of @handle.
  final VoidCallback? onAddUsername;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final handle = handleLine(
      username: d.username,
      bike: d.bike,
      homeArea: d.homeArea,
    );
    final muted = PasyarTextStyles.body.copyWith(
      fontSize: 14,
      color: PasyarColors.muted,
    );

    return ColoredBox(
      color: PasyarColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: _avatarSize - _overlap),
                child: ProfileCover(
                  image: d.cover,
                  leading: coverLeading,
                  actions: coverActions,
                  onEditCover: onEditCover,
                  busy: coverBusy,
                ),
              ),
              Positioned(
                left: PasyarSpacing.screen,
                right: PasyarSpacing.screen,
                bottom: 0,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: PasyarColors.card,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: PasyarShadows.floating,
                      ),
                      child: Avatar(
                        name: d.name,
                        image: d.avatar,
                        size: _avatarSize - 8,
                        radius: 20,
                      ),
                    ),
                    const Spacer(),
                    action,
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PasyarSpacing.screen,
              12,
              PasyarSpacing.screen,
              PasyarSpacing.screen,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    d.name,
                    style: PasyarTextStyles.body.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: PasyarColors.ink,
                      height: 1.2,
                    ),
                  ),
                ),
                if (d.username == null && onAddUsername != null)
                  GestureDetector(
                    onTap: onAddUsername,
                    child: Text(
                      [
                        '+ Add a username',
                        if (handle.isNotEmpty) handle,
                      ].join(' · '),
                      style: muted.copyWith(color: PasyarColors.accent),
                    ),
                  )
                else if (handle.isNotEmpty)
                  Text(handle, style: muted),
                if (d.bio case final bio? when bio.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      bio.trim(),
                      style: PasyarTextStyles.body.copyWith(fontSize: 14),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _FollowCounts(
                    followers: d.followers,
                    following: d.following,
                    onFollowers: onFollowers,
                    onFollowing: onFollowing,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: _StatTile(
                        value: formatTotalKm(d.riddenM),
                        label: 'km ridden',
                        highlight: true,
                      ),
                    ),
                    Expanded(
                      child: _StatTile(
                        value: '${d.loopsRidden}',
                        label: 'loops ridden',
                      ),
                    ),
                    Expanded(
                      child: _StatTile(value: '${d.posts}', label: 'posts'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowCounts extends StatelessWidget {
  const _FollowCounts({
    required this.followers,
    required this.following,
    this.onFollowers,
    this.onFollowing,
  });

  final int followers;
  final int following;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  @override
  Widget build(BuildContext context) {
    final base = PasyarTextStyles.body.copyWith(
      fontSize: 14,
      color: PasyarColors.muted,
    );
    final bold = base.copyWith(
      fontWeight: FontWeight.w700,
      color: PasyarColors.ink,
    );
    Widget part(int n, String label, VoidCallback? onTap) => Semantics(
      button: onTap != null,
      label: '$n $label',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        // Taller tap area than the text.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$n', style: bold),
                TextSpan(text: ' $label'),
              ],
            ),
            style: base,
          ),
        ),
      ),
    );
    // Wraps onto two lines with very large text instead of overflowing.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        part(followers, followers == 1 ? 'follower' : 'followers', onFollowers),
        Text(' · ', style: base),
        part(following, 'following', onFollowing),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final String value;
  final String label;

  /// km ridden: blue tint.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? PasyarColors.accentDark : PasyarColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? PasyarColors.accentTint : PasyarColors.ground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(
            value,
            maxLines: 1,
            style: PasyarTextStyles.body.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: color,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            style: PasyarTextStyles.label.copyWith(
              fontSize: 12,
              color: highlight ? PasyarColors.accentDark : PasyarColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// 38 px pill: Edit profile, Follow (blue) or Following (outlined).
class ProfilePillButton extends StatelessWidget {
  const ProfilePillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        // 38 px pill, 44 px tap area.
        child: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: outlined ? PasyarColors.card : PasyarColors.accent,
              shape: StadiumBorder(
                side: outlined
                    ? const BorderSide(color: PasyarColors.line, width: 1.5)
                    : BorderSide.none,
              ),
            ),
            child: Text(
              label,
              style: PasyarTextStyles.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1,
                color: outlined ? PasyarColors.ink : PasyarColors.card,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rides / My loops / Saved: 36 px pills, the active one filled with ink.
class ProfileTabs<T> extends StatelessWidget {
  const ProfileTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // Scrolls sideways when large text doesn't fit.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: _tabs(),
    );
  }

  Widget _tabs() {
    return Row(
      spacing: 8,
      children: [
        for (final MapEntry(key: tab, value: label) in tabs.entries)
          Semantics(
            button: true,
            selected: tab == selected,
            label: label,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(tab),
              child: SizedBox(
                height: PasyarSpacing.minTouch,
                child: Center(
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: tab == selected
                          ? PasyarColors.ink
                          : PasyarColors.card,
                      shape: StadiumBorder(
                        side: tab == selected
                            ? BorderSide.none
                            : const BorderSide(
                                color: PasyarColors.line,
                                width: 1.5,
                              ),
                      ),
                    ),
                    child: Text(
                      label,
                      style: PasyarTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: tab == selected
                            ? PasyarColors.card
                            : PasyarColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
