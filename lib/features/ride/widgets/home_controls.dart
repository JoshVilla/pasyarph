import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/generated_loop.dart';
import '../providers/ride_options_provider.dart';

/// "Starting from / Current location" pill.
class StartingFromPill extends StatelessWidget {
  const StartingFromPill({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Starting from current location',
      excludeSemantics: true,
      child: FloatingPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            const CustomPaint(
              size: Size.square(18),
              painter: _CrosshairPainter(),
            ),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Starting from',
                    maxLines: 1,
                    style: PasyarTextStyles.label.copyWith(
                      fontSize: 12,
                      height: 1.15,
                    ),
                  ),
                  Text(
                    'Current location',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PasyarTextStyles.bodyStrong.copyWith(height: 1.15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The mockup's location icon: a small ring with four ticks (no outer ring,
/// unlike Lucide's "locate").
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
            spacing: 14,
            children: [
              const Icon(
                LucideIcons.mapPinOff,
                size: 24,
                color: PasyarColors.accentDark,
              ),
              Expanded(
                child: Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(
                        text: 'Location is off',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' — Pasyar needs it to build loops'),
                    ],
                  ),
                  style: PasyarTextStyles.body.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
          PrimaryButton(
            label: canAsk ? 'ALLOW LOCATION' : 'OPEN SETTINGS',
            icon: canAsk ? LucideIcons.mapPin : LucideIcons.settings,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

/// White card floating over the map: a spinner while something loads, or an
/// icon with a message (errors, warnings).
class MapNotice extends StatelessWidget {
  const MapNotice({super.key, required this.text, this.icon}) : loading = false;

  const MapNotice.loading({super.key, required this.text})
    : loading = true,
      icon = null;

  final String text;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: PasyarColors.card,
          borderRadius: BorderRadius.circular(PasyarRadius.panel),
          boxShadow: PasyarShadows.floating,
        ),
        child: Row(
          spacing: 14,
          children: [
            SizedBox.square(
              dimension: 24,
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: PasyarColors.accent,
                      ),
                    )
                  : Icon(
                      icon ?? LucideIcons.info,
                      size: 24,
                      color: PasyarColors.accentDark,
                    ),
            ),
            Expanded(
              child: Text(
                text,
                style: PasyarTextStyles.body.copyWith(height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "WHERE TO TODAY?" sheet: duration, avoid toggles, GENERATE LOOP.
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

  @override
  Widget build(BuildContext context) {
    return BottomSheetPanel(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text('WHERE TO TODAY?', style: PasyarTextStyles.screenTitle(30)),
            Text(
              "Pick how long. We'll make the loop.",
              style: PasyarTextStyles.body.copyWith(
                height: 1.2,
                color: PasyarColors.muted,
              ),
            ),
          ],
        ),
        // Two rows of two: four 72 px cards in one row would be too narrow
        // for MULTI-DAY and for gloves.
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
                        onTap: () => options.duration = d,
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
        PrimaryButton(
          label: 'GENERATE LOOP',
          icon: LucideIcons.rotateCw,
          loading: generating,
          onPressed: onGenerate,
        ),
      ],
    );
  }
}
