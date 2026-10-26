import 'package:flutter/material.dart';

import '../theme/pasyar_theme.dart';
import '../../data/models/generated_loop.dart';

/// Duration choice card for the "Where to today?" sheet.
/// Matches design/mockups/01-home.html: icon + title + subtitle on the left,
/// right-side label (e.g. "Back 1:40 PM"), selected = accentTint fill + 2 px
/// accent border + accentDark text.
class LoopDurationCard extends StatelessWidget {
  const LoopDurationCard({
    super.key,
    required this.duration,
    required this.selected,
    required this.onTap,
  });

  final LoopDuration duration;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? PasyarColors.accentDark : PasyarColors.ink;
    final subtitleColor = selected
        ? PasyarColors.accentDark
        : PasyarColors.muted;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SizedBox(
        height: 72,
        child: Material(
          color: selected ? PasyarColors.accentTint : PasyarColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PasyarRadius.choiceCard),
            side: selected
                ? const BorderSide(color: PasyarColors.accent, width: 2)
                : const BorderSide(color: PasyarColors.accentTint, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Icon chip on the left.
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected ? PasyarColors.accent : PasyarColors.line,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      duration.icon,
                      size: 18,
                      color: selected ? PasyarColors.card : PasyarColors.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title + subtitle.
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          duration.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PasyarTextStyles.choiceTitle.copyWith(
                            fontSize: 18,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right-side label.
                  Text(
                    duration.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PasyarTextStyles.label.copyWith(
                      fontSize: 13,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
