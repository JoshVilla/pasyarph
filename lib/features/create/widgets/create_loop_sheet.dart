import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/club.dart';
import '../../../data/models/enums.dart';
import '../loop_builder.dart';

/// Height of the open sheet (the mockup's 472 px, including its 36 px
/// bottom padding).
const createSheetHeight = 472.0;
const _bottomPadding = 36.0;

/// How much of the sheet shows while building: the handle and the totals
/// bar with DONE (plus the phone's bottom inset).
const createSheetPeek = 104.0;

/// Visibility segments. Group loops are club loops, as everywhere else.
const _visibilityLabels = {
  LoopVisibility.public: 'Public',
  LoopVisibility.club: 'Club',
  LoopVisibility.private: 'Private',
};

/// Create sheet. Its first row is the peek bar shown while building: the
/// live totals and DONE (which raises the sheet). Below: loop name, a
/// caption folded away behind "Add a caption", who can see it, SAVE and
/// SHARE LINK.
class CreateLoopSheet extends StatefulWidget {
  const CreateLoopSheet({
    super.key,
    required this.name,
    required this.caption,
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
    required this.collapsed,
    required this.onDone,
    this.saving = false,
    this.bottomInset = 0,
  });

  final TextEditingController name;
  final TextEditingController caption;
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

  /// The sheet is lowered to its peek: the bar shows DONE.
  final bool collapsed;

  /// Raises the sheet; null while there are no points.
  final VoidCallback? onDone;

  /// Extra bottom padding for the phone's navigation bar.
  final double bottomInset;

  @override
  State<CreateLoopSheet> createState() => _CreateLoopSheetState();
}

class _CreateLoopSheetState extends State<CreateLoopSheet> {
  /// The caption field shows once asked for, or when there's a caption.
  late bool _captionOpen = widget.caption.text.isNotEmpty;

  String get _visibilityHelp => switch (widget.visibility) {
    LoopVisibility.public => 'Everyone on Pasyar can see and ride this loop.',
    LoopVisibility.private => 'Only you will see this loop.',
    LoopVisibility.club when widget.clubs == null => 'Loading your clubs…',
    LoopVisibility.club when widget.club == null =>
      'Join or create a club under Me to share loops with it.',
    LoopVisibility.club =>
      'Only members of ${widget.club!.name} will see this loop.',
  };

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final canPickClub =
        w.visibility == LoopVisibility.club && (w.clubs?.length ?? 0) > 1;

    return Container(
      decoration: BoxDecoration(
        color: PasyarColors.of(context).card,
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
                _bottomPadding + w.bottomInset,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 14,
                children: [
                  const DragHandle(),
                  _TotalsBar(
                    line: loopTotalsLine(
                      w.totals,
                      points: w.pointCount,
                      failed: w.routeFailed,
                    ),
                    detail: w.pointCount == 0
                        ? 'Tap the map to add your first point'
                        : pointsLabel(w.pointCount),
                    showDone: w.collapsed,
                    onDone: w.onDone,
                  ),
                  // Hidden (and inert) while the sheet is lowered, so
                  // nothing peeks out under the totals bar.
                  Expanded(
                    child: IgnorePointer(
                      ignoring: w.collapsed,
                      child: AnimatedOpacity(
                        opacity: w.collapsed ? 0 : 1,
                        duration: PasyarMotion.duration(
                          context,
                          PasyarMotion.feedback,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 14,
                          children: [
                            PasyarTextField(
                              label: 'Loop name',
                              controller: w.name,
                              hint: 'Name your loop',
                              height: 48,
                              maxLength: 80,
                              textStyle: PasyarTextStyles.of(
                                context,
                              ).choiceTitle.copyWith(fontSize: 22, height: 1.2),
                              enabled: !w.moving,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                            ),
                            if (_captionOpen)
                              PasyarTextField(
                                label: 'Caption',
                                controller: w.caption,
                                hint: 'Describe your loop',
                                maxLines: 3,
                                maxLength: 500,
                                enabled: !w.moving,
                                textCapitalization:
                                    TextCapitalization.sentences,
                              )
                            else
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TextButton.icon(
                                  onPressed: w.moving
                                      ? null
                                      : () =>
                                            setState(() => _captionOpen = true),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(
                                      0,
                                      PasyarSpacing.minTouch,
                                    ),
                                    padding: EdgeInsets.zero,
                                    foregroundColor: PasyarColors.of(
                                      context,
                                    ).accentDark,
                                  ),
                                  icon: const Icon(LucideIcons.plus, size: 18),
                                  label: Text(
                                    'Add a caption',
                                    style: PasyarTextStyles.of(context)
                                        .bodyStrong
                                        .copyWith(
                                          color: PasyarColors.of(
                                            context,
                                          ).accentDark,
                                        ),
                                  ),
                                ),
                              ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 8,
                              children: [
                                Text(
                                  'Who can see it',
                                  style: PasyarTextStyles.of(
                                    context,
                                  ).fieldLabel,
                                ),
                                SegmentedChoice<LoopVisibility>(
                                  semanticLabel: 'Visibility',
                                  options: _visibilityLabels,
                                  selected: w.visibility,
                                  onChanged: w.onVisibility,
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _visibilityHelp,
                                        style: PasyarTextStyles.of(
                                          context,
                                        ).label,
                                      ),
                                    ),
                                    if (canPickClub)
                                      TextButton(
                                        onPressed: w.onPickClub,
                                        style: TextButton.styleFrom(
                                          minimumSize: const Size(
                                            PasyarSpacing.minTouch,
                                            PasyarSpacing.minTouch,
                                          ),
                                          foregroundColor: PasyarColors.of(
                                            context,
                                          ).accentDark,
                                        ),
                                        child: Text(
                                          'Change',
                                          style: PasyarTextStyles.of(context)
                                              .fieldLabel
                                              .copyWith(
                                                color: PasyarColors.of(
                                                  context,
                                                ).accentDark,
                                              ),
                                        ),
                                      ),
                                  ],
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
                                    onPressed: w.onSave,
                                    loading: w.saving,
                                  ),
                                ),
                                Expanded(
                                  child: PrimaryButton(
                                    label: 'SHARE LINK',
                                    icon: LucideIcons.link,
                                    onPressed: w.onShare,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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

/// The peek bar: "96 KM · 3 H 10" at stat size over "3 points · closes back
/// to start", and DONE while the sheet is lowered.
class _TotalsBar extends StatelessWidget {
  const _TotalsBar({
    required this.line,
    required this.detail,
    required this.showDone,
    required this.onDone,
  });

  final String line;
  final String detail;
  final bool showDone;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PasyarTextStyles.of(
                      context,
                    ).statValue.copyWith(height: 1),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PasyarTextStyles.of(
                      context,
                    ).label.copyWith(height: 1.2),
                  ),
                ],
              ),
            ),
          ),
          if (showDone)
            SizedBox(
              width: 120,
              child: PrimaryButton(label: 'DONE', onPressed: onDone),
            ),
        ],
      ),
    );
  }
}

/// Picks one of the rider's clubs for a club loop.
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
        Text('SHARE WITH', style: PasyarTextStyles.of(context).screenTitle(24)),
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
