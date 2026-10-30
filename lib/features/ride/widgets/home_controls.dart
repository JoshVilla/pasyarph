import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/generated_loop.dart';
import '../providers/ride_options_provider.dart';

/// "Starting from your location" pill with a blue dot; "Location is off"
/// with a grey one when location can't be used ([on] false).
class StartingFromPill extends StatelessWidget {
  const StartingFromPill({super.key, this.on = true});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final text = on ? 'Starting from your location' : 'Location is off';
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: FloatingPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: on ? PasyarColors.accent : PasyarColors.riddenRoute,
                shape: BoxShape.circle,
              ),
            ),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PasyarTextStyles.bodyStrong.copyWith(
                  height: 1.15,
                  color: on ? PasyarColors.ink : PasyarColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inside the sheet, above GENERATE LOOP, when location can't be used.
/// [status] must not be [LocationStatus.on] or [LocationStatus.checking].
class LocationOffBanner extends StatelessWidget {
  const LocationOffBanner({
    super.key,
    required this.status,
    required this.onPressed,
  });

  final LocationStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final canAsk = status == LocationStatus.denied;
    final message = switch (status) {
      LocationStatus.serviceOff => "Your phone's location is off.",
      _ => 'Pasyar needs your location to build a loop from where you are.',
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PasyarColors.ground,
          borderRadius: BorderRadius.circular(PasyarRadius.panel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                const Icon(
                  LucideIcons.mapPinOff,
                  size: 22,
                  color: PasyarColors.accentDark,
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Location is off. ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: message),
                      ],
                    ),
                    style: PasyarTextStyles.body.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
            SecondaryButton(
              label: canAsk ? 'ALLOW LOCATION' : 'OPEN SETTINGS',
              icon: canAsk ? LucideIcons.mapPin : LucideIcons.settings,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}

/// Why the last Generate failed, shown right above the button.
class SheetError extends StatelessWidget {
  const SheetError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          const Icon(
            LucideIcons.circleAlert,
            size: 20,
            color: PasyarColors.accentDark,
          ),
          Expanded(
            child: Text(
              message,
              style: PasyarTextStyles.body.copyWith(
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: PasyarColors.accentDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Location is on but there's no GPS fix yet; GENERATE LOOP waits for it.
class SheetWaiting extends StatelessWidget {
  const SheetWaiting({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        spacing: 10,
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: PasyarColors.accent,
            ),
          ),
          Text(
            'Finding your location…',
            style: PasyarTextStyles.body.copyWith(color: PasyarColors.muted),
          ),
        ],
      ),
    );
  }
}

/// The sheet's sentence for a choice: "I'VE GOT ABOUT " + "4 HRS".
(String, String) headlineFor(LoopDuration d, int days) => switch (d) {
  LoopDuration.quick => ("I'VE GOT ABOUT ", '1 HR'),
  LoopDuration.halfDay => ("I'VE GOT ABOUT ", '4 HRS'),
  LoopDuration.fullDay => ("I'VE GOT ", 'ALL DAY'),
  LoopDuration.multiDay => ("I'VE GOT ", '$days DAYS'),
};

/// "WHERE TO TODAY?" answered as one line the rider finishes: the
/// sentence, four duration cards, the avoid toggles, and GENERATE LOOP.
/// [notice] (location trouble, or why Generate failed) sits above the
/// button.
class WhereToSheet extends StatelessWidget {
  const WhereToSheet({
    super.key,
    required this.options,
    required this.onGenerate,
    this.generating = false,
    this.notice,
    this.maxHeight,
  });

  final RideOptionsProvider options;

  /// Tallest the sheet may grow before its content scrolls (it must stop
  /// below the controls floating over the map).
  final double? maxHeight;

  /// Null disables the button (no location yet).
  final VoidCallback? onGenerate;

  /// Shows a spinner in the button while a loop is being built.
  final bool generating;

  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final (lead, choice) = headlineFor(options.duration, options.days);
    final instant = MediaQuery.disableAnimationsOf(context);
    return BottomSheetPanel(
      gap: 14,
      maxHeight: maxHeight,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Semantics(
              header: true,
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: instant
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                child: Text.rich(
                  key: ValueKey(lead + choice),
                  TextSpan(
                    children: [
                      TextSpan(text: lead),
                      TextSpan(
                        text: choice,
                        style: const TextStyle(color: PasyarColors.accent),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  style: PasyarTextStyles.screenTitle(30),
                ),
              ),
            ),
            Text(
              "Pick how long. We'll make the loop.",
              style: PasyarTextStyles.body.copyWith(
                height: 1.2,
                color: PasyarColors.muted,
              ),
            ),
          ],
        ),
        // Two rows of two: four cards in one row would be too narrow for
        // MULTI-DAY and for gloves.
        Column(
          spacing: PasyarSpacing.buttonGap,
          children: [
            for (var i = 0; i < LoopDuration.values.length; i += 2)
              Row(
                spacing: PasyarSpacing.buttonGap,
                children: [
                  for (final d in LoopDuration.values.skip(i).take(2))
                    Expanded(
                      child: ChoiceCard(
                        title: d.title,
                        subtitle: d.subtitle,
                        selected: options.duration == d,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          options.duration = d;
                        },
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (options.duration == LoopDuration.multiDay)
          Row(
            spacing: 12,
            children: [
              Text('Days', style: PasyarTextStyles.fieldLabel),
              Expanded(
                child: SegmentedChoice<int>(
                  semanticLabel: 'Days',
                  options: {for (var d = 2; d <= 7; d++) d: '$d'},
                  selected: options.days,
                  onChanged: (d) => options.days = d,
                ),
              ),
            ],
          ),
        Row(
          spacing: PasyarSpacing.buttonGap,
          children: [
            Expanded(
              child: PillToggle(
                label: 'Avoid highways',
                value: options.avoidHighways,
                onChanged: (v) => options.avoidHighways = v,
              ),
            ),
            Expanded(
              child: PillToggle(
                label: 'Avoid unpaved',
                value: options.avoidUnpaved,
                onChanged: (v) => options.avoidUnpaved = v,
              ),
            ),
          ],
        ),
        ?notice,
        PrimaryButton(
          label: 'GENERATE LOOP',
          // Not the Create tab's route icon: this makes the loop for you.
          icon: LucideIcons.sparkles,
          loading: generating,
          onPressed: onGenerate,
        ),
      ],
    );
  }
}
