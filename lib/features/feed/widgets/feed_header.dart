import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/feed_provider.dart';

/// Top of the feed (mockup 5): FEED with search and notifications, the
/// "Share a ride or a loop…" row, and the filter chips.
class FeedHeader extends StatelessWidget {
  const FeedHeader({
    super.key,
    required this.myName,
    required this.filter,
    required this.onFilter,
    required this.onShare,
    required this.onAddPhotos,
    required this.onSearch,
    required this.onNotifications,
    this.myAvatar,
    this.unreadNotifications = false,
  });

  final String myName;
  final ImageProvider? myAvatar;
  final FeedFilter filter;
  final ValueChanged<FeedFilter> onFilter;
  final VoidCallback onShare;
  final VoidCallback onAddPhotos;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final bool unreadNotifications;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: PasyarColors.card,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PasyarSpacing.screen,
          top + 8,
          PasyarSpacing.screen,
          12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'FEED',
                    style: PasyarTextStyles.screenTitle(
                      32,
                    ).copyWith(letterSpacing: 0.5),
                  ),
                ),
                RoundIconButton.ground(
                  icon: LucideIcons.search,
                  iconSize: 20,
                  semanticLabel: 'Search',
                  onPressed: onSearch,
                ),
                const SizedBox(width: 8),
                Stack(
                  children: [
                    RoundIconButton.ground(
                      icon: LucideIcons.bell,
                      iconSize: 20,
                      semanticLabel: unreadNotifications
                          ? 'Notifications, new'
                          : 'Notifications',
                      onPressed: onNotifications,
                    ),
                    if (unreadNotifications)
                      Positioned(
                        top: 9,
                        right: 10,
                        child: IgnorePointer(
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: PasyarColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: PasyarColors.ground,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Row(
              spacing: 10,
              children: [
                Avatar(
                  name: myName,
                  image: myAvatar,
                  size: 40,
                  color: PasyarColors.ink,
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: onShare,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        decoration: ShapeDecoration(
                          shape: const StadiumBorder(
                            side: BorderSide(
                              color: PasyarColors.line,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: Text(
                          'Share a ride or a loop…',
                          style: PasyarTextStyles.body.copyWith(
                            height: 1.2,
                            color: PasyarColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Post a ride',
                  excludeSemantics: true,
                  child: Material(
                    color: PasyarColors.accentTint,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onAddPhotos,
                      child: const SizedBox.square(
                        dimension: 44,
                        child: Icon(
                          LucideIcons.image,
                          size: 20,
                          color: PasyarColors.accentDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Chips are 36 px tall like the mockup; their 44 px touch area
            // overflows the row.
            SizedBox(
              height: 36,
              child: OverflowBox(
                maxHeight: PasyarSpacing.minTouch,
                alignment: Alignment.centerLeft,
                child: // Scrolls sideways when large text makes the chips too wide.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: PasyarSpacing.chipGap,
                    children: [
                      for (final f in FeedFilter.values)
                        PasyarFilterChip(
                          label: f.label,
                          selected: f == filter,
                          onTap: () => onFilter(f),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
