import 'package:flutter/material.dart';

import '../theme/pasyar_theme.dart';

/// Selectable card. With a [subtitle] it is the 72 px duration card
/// (QUICK / about 1 hr); without one it is the 52 px bike-type card
/// (SCOOTER, UNDERBONE, ...).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null;
    final textColor = selected ? PasyarColors.accentDark : PasyarColors.ink;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SizedBox(
        height: hasSubtitle ? 72 : 52,
        child: Material(
          color: selected ? PasyarColors.accentTint : PasyarColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PasyarRadius.choiceCard),
            side: selected
                ? const BorderSide(color: PasyarColors.accent, width: 2)
                : const BorderSide(color: PasyarColors.line, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 2,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  style: PasyarTextStyles.choiceTitle.copyWith(
                    fontSize: hasSubtitle ? 20 : 19,
                    color: textColor,
                  ),
                ),
                if (hasSubtitle)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    style: PasyarTextStyles.label.copyWith(
                      color: selected
                          ? PasyarColors.accentDark
                          : PasyarColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
