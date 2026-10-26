import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/generated_loop.dart';
import '../providers/ride_options_provider.dart';

/// "Starting from your location" pill with a green dot.
class StartingFromPill extends StatelessWidget {
  const StartingFromPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Starting from your location',
      excludeSemantics: true,
      child: FloatingPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: PasyarColors.accent,
                shape: BoxShape.circle,
              ),
            ),
            Flexible(
              child: Text(
                'Starting from your location',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PasyarTextStyles.bodyStrong.copyWith(height: 1.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The mockup's location icon: a small ring with four ticks (no outer ring,
/// unlike Lucide's "locate"). Kept for reuse elsewhere.
class _CrosshairPainter extends CustomPainter {
  const _CrosshairPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final paint = Paint()
      ..color = PasyarColors.rider
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * s
      ..strokeCap = StrokeCap.round;
    Offset p(double x, double y) => Offset(x * s, y * s);
    canvas
      ..drawCircle(p(12, 12), 3 * s, paint)
      ..drawLine(p(12, 2), p(12, 5), paint)
      ..drawLine(p(12, 19), p(12, 22), paint)
      ..drawLine(p(2, 12), p(5, 12), paint)
      ..drawLine(p(19, 12), p(22, 12), paint);
  }

  @override
  bool shouldRepaint(_CrosshairPainter oldDelegate) => false;
}

/// Shown over the map when location can't be used. [status] must not be
/// [LocationStatus.on] or [LocationStatus.checking].
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PasyarColors.card,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
        boxShadow: PasyarShadows.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            spacing: 10,
            children: [
              Icon(
                canAsk ? LucideIcons.alertCircle : LucideIcons.wifiOff,
                size: 24,
                color: PasyarColors.accentDark,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canAsk ? 'Location access is off' : 'No location fix',
                      style: PasyarTextStyles.body.copyWith(
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      canAsk
                          ? 'Tap to allow Pasyar to use your location.'
                          : 'Waiting for GPS…',
                      style: PasyarTextStyles.body.copyWith(
                        height: 1.35,
                        color: PasyarColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canAsk)
            SecondaryButton(
              label: 'Allow location',
              icon: LucideIcons.mapPin,
              onPressed: onPressed,
            ),
        ],
      ),
    );
  }
}

/// "WHERE TO TODAY?" sheet: duration cards, avoid toggle, generate button.
class WhereToSheet extends StatelessWidget {
  const WhereToSheet({
    super.key,
    required this.options,
    required this.onGenerate,
    this.generating = false,
  });

  final RideOptionsProvider options;

  /// Null disables the button (no location yet).
  final VoidCallback? onGenerate;

  /// Shows a spinner in the button while a loop is being built.
  final bool generating;

  /// Button label based on the selected duration.
  String _buttonLabel(BuildContext context) {
    switch (options.duration) {
      case LoopDuration.quick:
        return 'Generate Quick loop';
      case LoopDuration.halfDay:
        return 'Generate Half-day loop';
      case LoopDuration.fullDay:
        return 'Generate Full-day loop';
      case LoopDuration.multiDay:
        return 'Plan Multi-day trip';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetPanel(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text('Where to today?', style: PasyarTextStyles.screenTitle(25)),
          ],
        ),
        // Single column of duration cards.
        Column(
          spacing: PasyarSpacing.buttonGap,
          children: [
            for (final d in LoopDuration.values)
              LoopDurationCard(
                duration: d,
                selected: options.duration == d,
                onTap: () => options.duration = d,
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
          ],
        ),
        PrimaryButton(
          label: _buttonLabel(context),
          icon: LucideIcons.rotateCw,
          loading: generating,
          onPressed: onGenerate,
        ),
      ],
    );
  }
}
