import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/pasyar_theme.dart';

/// White sheet with 24 px top corners, the sheet shadow and a drag handle.
/// Children are laid out in a column with [gap] between them.
class BottomSheetPanel extends StatelessWidget {
  const BottomSheetPanel({
    super.key,
    required this.children,
    this.gap = PasyarSpacing.groupGap,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
    this.showHandle = true,
  });

  final List<Widget> children;
  final double gap;
  final EdgeInsets padding;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: PasyarColors.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PasyarRadius.sheet),
        ),
        boxShadow: PasyarShadows.sheet,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [if (showHandle) const DragHandle(), ...children],
      ),
    );
  }
}

class DragHandle extends StatelessWidget {
  const DragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: PasyarColors.lineStrong,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// 48 px white pill floating over the map ("Starting from", "HALF-DAY LOOP").
class FloatingPill extends StatelessWidget {
  const FloatingPill({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: PasyarShadows.floating,
      ),
      child: Material(
        color: PasyarColors.card,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small muted label over a big condensed number.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.small = false,
  });

  final String label;
  final String value;
  final Color? valueColor;

  /// 22 px value, used inside feed cards.
  final bool small;

  @override
  Widget build(BuildContext context) {
    final valueStyle = small
        ? PasyarTextStyles.statValueSmall
        : PasyarTextStyles.statValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Text(label, style: PasyarTextStyles.label, maxLines: 1),
        Text(value, maxLines: 1, style: valueStyle.copyWith(color: valueColor)),
      ],
    );
  }
}

/// Three [StatBlock]s in equal columns, 8 px apart.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [for (final child in children) Expanded(child: child)],
    );
  }
}

/// `ground` panel with a thumbnail, overline, name and detail line.
class StopCard extends StatelessWidget {
  const StopCard({
    super.key,
    required this.overline,
    required this.name,
    this.detail,
    this.image,
    this.onTap,
  });

  final String overline;
  final String name;
  final String? detail;
  final ImageProvider? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PasyarColors.ground,
      borderRadius: BorderRadius.circular(PasyarRadius.panel),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            spacing: 14,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: PasyarColors.lineStrong,
                  borderRadius: BorderRadius.circular(PasyarRadius.thumbnail),
                  image: image == null
                      ? null
                      : DecorationImage(image: image!, fit: BoxFit.cover),
                ),
                child: image == null
                    ? const Icon(
                        LucideIcons.image,
                        size: 24,
                        color: PasyarColors.muted,
                      )
                    : null,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      overline.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PasyarTextStyles.overline,
                    ),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PasyarTextStyles.bodyLarge,
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PasyarTextStyles.label.copyWith(fontSize: 14),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `ground` panel with an `accentDark` icon and a bold lead phrase.
class SafetyRow extends StatelessWidget {
  const SafetyRow({
    super.key,
    required this.icon,
    required this.lead,
    required this.text,
  });

  final IconData icon;

  /// Bold opening phrase, e.g. "Mount your phone".
  final String lead;

  /// Rest of the sentence, e.g. " before you ride." (include the leading
  /// space).
  final String text;

  @override
  Widget build(BuildContext context) {
    final style = PasyarTextStyles.body.copyWith(height: 1.35);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: PasyarColors.ground,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
      ),
      child: Row(
        spacing: 14,
        children: [
          Icon(icon, size: 24, color: PasyarColors.accentDark),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: lead,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// "STEP X OF N" overline over N equal 6 px segments.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.total})
    : assert(step >= 1 && step <= total);

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $step of $total',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Text('STEP $step OF $total', style: PasyarTextStyles.overline),
          Row(
            spacing: 6,
            children: [
              for (var i = 1; i <= total; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= step
                          ? PasyarColors.accent
                          : PasyarColors.line,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 1 px rules either side of muted text ("or log in with email").
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    const rule = Expanded(
      child: Divider(height: 1, thickness: 1, color: PasyarColors.line),
    );
    return Row(
      spacing: 12,
      children: [
        rule,
        Text(
          text,
          style: PasyarTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w400,
            color: PasyarColors.muted,
          ),
        ),
        rule,
      ],
    );
  }
}
