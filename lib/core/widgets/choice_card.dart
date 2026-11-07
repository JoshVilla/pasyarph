import 'package:flutter/material.dart';

import '../theme/pasyar_theme.dart';
import 'motion.dart';

/// Selectable card. With a [subtitle] it is the 72 px duration card
/// (QUICK / about 1 hr); without one it is the 52 px card (report reasons).
/// With an [image] it is the 104 px bike-type card: the picture above the
/// title (SCOOTER, UNDERBONE, ...).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.image,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback? onTap;

  /// A picture above the title, on a transparent background.
  final ImageProvider? image;

  static const imageCardHeight = 104.0;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null;
    final image = this.image;
    final textColor = selected
        ? PasyarColors.of(context).accentDark
        : PasyarColors.of(context).ink;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SizedBox(
        height: image != null
            ? imageCardHeight
            : hasSubtitle
            ? 72
            : 52,
        child: Material(
          animationDuration: PasyarMotion.duration(
            context,
            PasyarMotion.feedback,
          ),
          color: selected
              ? PasyarColors.of(context).accentTint
              : PasyarColors.of(context).card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PasyarRadius.choiceCard),
            side: selected
                ? BorderSide(color: PasyarColors.of(context).accent, width: 2)
                : BorderSide(color: PasyarColors.of(context).line, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 5,
              children: [
                if (image != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 14, 32, 4),
                      child: Image(
                        image: image,
                        fit: BoxFit.contain,
                        // Decorative: the title says what it is.
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PasyarTextStyles.of(context).choiceTitle.copyWith(
                    fontSize: hasSubtitle ? 17 : 16,
                    color: textColor,
                  ),
                ),
                if (image != null) const SizedBox(height: 8),
                if (hasSubtitle)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    style: PasyarTextStyles.of(context).label.copyWith(
                      color: selected
                          ? PasyarColors.of(context).accentDark
                          : PasyarColors.of(context).muted,
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
