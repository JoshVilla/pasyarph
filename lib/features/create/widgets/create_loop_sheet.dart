import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/club.dart';
import '../../../data/models/enums.dart';
import '../../ride/loop_stats.dart';
import '../loop_builder.dart';

/// Height of the sheet in design/mockups/06-create-loop.html (844 − 372),
/// including its 36 px bottom padding.
const createSheetHeight = 472.0;
const _bottomPadding = 36.0;

/// Visibility segments as the mockup labels them: clubs are "Group".
const _visibilityLabels = {
  LoopVisibility.public: 'Public',
  LoopVisibility.club: 'Group',
  LoopVisibility.private: 'Private',
};

/// Create sheet: loop name, live distance and ride time, visibility, SAVE
/// and SHARE LINK.
class CreateLoopSheet extends StatelessWidget {
  const CreateLoopSheet({
    super.key,
    required this.name,
    required this.pointCount,
    required this.totals,
    required this.routing,
    required this.routeFailed,
    required this.visibility,
    required this.clubs,
    required this.club,
    required this.moving,
    required this.onVisibility,
    required this.onPickClub,
    required this.onSave,
    required this.onShare,
    this.saving = false,
    this.bottomInset = 0,
  });

  final TextEditingController name;
  final int pointCount;
  final LoopTotals totals;
  final bool routing;
  final bool routeFailed;
  final LoopVisibility visibility;

  /// The rider's clubs; null while loading.
  final List<Club>? clubs;
  final Club? club;

  /// Faster than 10 km/h: no typing or saving.
  final bool moving;
  final ValueChanged<LoopVisibility> onVisibility;
  final VoidCallback? onPickClub;

  /// Null disables the button.
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final bool saving;

  /// Extra bottom padding for the phone's navigation bar.
  final double bottomInset;

  String get _stats {
    if (pointCount == 0) return '0 km · 0 min';
    if (totals.complete) {
      return '${formatDistance(totals.distanceM)} · '
          '${formatRideTime(totals.durationS)}';
    }
    if (routeFailed) return '— km';
    return 'Finding roads…';
  }

  String get _visibilityHelp => switch (visibility) {
    LoopVisibility.public => 'Everyone on Pasyar can see and ride this loop.',
    LoopVisibility.private => 'Only you will see this loop.',
    LoopVisibility.club when clubs == null => 'Loading your clubs…',
    LoopVisibility.club when club == null =>
      'Join a club to share loops with a group.',
    LoopVisibility.club => 'Only members of ${club!.name} will see this loop.',
  };

  @override
  Widget build(BuildContext context) {
    final muted = PasyarTextStyles.bodySmall.copyWith(
      fontWeight: FontWeight.w400,
      color: PasyarColors.muted,
      height: 1.2,
    );
    final canPickClub =
        visibility == LoopVisibility.club && (clubs?.length ?? 0) > 1;

    return Container(
      decoration: const BoxDecoration(
        color: PasyarColors.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PasyarRadius.sheet),
        ),
        boxShadow: PasyarShadows.sheet,
      ),
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                PasyarSpacing.sheet,
                12,
                PasyarSpacing.sheet,
                _bottomPadding + bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  const DragHandle(),
                  PasyarTextField(
                    label: 'Loop name',
                    controller: name,
                    hint: 'Name your loop',
                    height: 48,
                    maxLength: 80,
                    textStyle: PasyarTextStyles.choiceTitle.copyWith(
                      fontSize: 22,
                      height: 1.2,
                    ),
                    enabled: !moving,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      Text(
                        _stats,
                        style: PasyarTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      Text('·', style: muted),
                      Flexible(
                        child: Text(
                          pointsLabel(pointCount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: muted,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      Text('Who can see it', style: PasyarTextStyles.fieldLabel),
                      SegmentedChoice<LoopVisibility>(
                        semanticLabel: 'Visibility',
                        options: _visibilityLabels,
                        selected: visibility,
                        onChanged: onVisibility,
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: canPickClub ? onPickClub : null,
                        child: Text.rich(
                          TextSpan(
                            text: _visibilityHelp,
                            children: [
                              if (canPickClub)
                                TextSpan(
                                  text: '  Change',
                                  style: PasyarTextStyles.fieldLabel.copyWith(
                                    color: PasyarColors.accentDark,
                                  ),
                                ),
                            ],
                          ),
                          style: PasyarTextStyles.label,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    spacing: PasyarSpacing.buttonGap,
                    children: [
                      SizedBox(
                        width: 120,
                        child: SecondaryButton(
                          label: 'SAVE',
                          onPressed: onSave,
                          loading: saving,
                        ),
                      ),
                      Expanded(
                        child: PrimaryButton(
                          label: 'SHARE LINK',
                          icon: LucideIcons.link,
                          onPressed: onShare,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks one of the rider's clubs for a Group loop.
Future<String?> showClubPicker(
  BuildContext context, {
  required List<Club> clubs,
  String? selected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => BottomSheetPanel(
      gap: 8,
      children: [
        Text('SHARE WITH', style: PasyarTextStyles.screenTitle(24)),
        for (final c in clubs)
          ChoiceCard(
            title: c.name,
            selected: c.id == selected,
            onTap: () => Navigator.of(context).pop(c.id),
          ),
      ],
    ),
  );
}
