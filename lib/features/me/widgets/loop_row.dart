import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/loop.dart';
import '../../ride/loop_stats.dart';

/// "Public", "Group", "Private" as the Create sheet labels them.
String visibilityLabel(LoopVisibility v) => switch (v) {
  LoopVisibility.public => 'Public',
  LoopVisibility.club => 'Group',
  LoopVisibility.private => 'Private',
};

IconData visibilityIcon(LoopVisibility v) => switch (v) {
  LoopVisibility.public => LucideIcons.globe,
  LoopVisibility.club => LucideIcons.users,
  LoopVisibility.private => LucideIcons.lock,
};

/// Small white pill with who can see a loop.
class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge(this.visibility, {super.key});

  final LoopVisibility visibility;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: ShapeDecoration(
        color: PasyarColors.card,
        shape: const StadiumBorder(
          side: BorderSide(color: PasyarColors.lineStrong),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(visibilityIcon(visibility), size: 13, color: PasyarColors.muted),
          Text(
            visibilityLabel(visibility),
            style: PasyarTextStyles.label.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PasyarColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// A loop on the Me tab: badge, name, km and time on `ground`. Tapping it
/// rides it from where the rider is; the ⋯ button opens [onMore].
class LoopRow extends StatelessWidget {
  const LoopRow({
    super.key,
    required this.loop,
    required this.onTap,
    required this.onMore,
    this.detail,
  });

  final Loop loop;
  final VoidCallback onTap;
  final VoidCallback onMore;

  /// Next to the badge, e.g. "Made by you".
  final String? detail;

  @override
  Widget build(BuildContext context) {
    // Loops under 1.8 km have nothing left after the home privacy trim.
    final rideable = loop.sharedRoute != null;
    return Material(
      color: PasyarColors.ground,
      borderRadius: BorderRadius.circular(PasyarRadius.panel),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: rideable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Semantics(
                  button: rideable,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          VisibilityBadge(loop.visibility),
                          if (detail != null)
                            Flexible(
                              child: Text(
                                detail!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PasyarTextStyles.label,
                              ),
                            ),
                        ],
                      ),
                      Text(
                        loop.name,
                        style: PasyarTextStyles.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${formatDistance(loop.distanceM)} · '
                        '${formatRideTime(loop.durationS)}',
                        style: PasyarTextStyles.label,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onMore,
                tooltip: 'More',
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                icon: const Icon(
                  LucideIcons.ellipsis,
                  size: 22,
                  color: PasyarColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
