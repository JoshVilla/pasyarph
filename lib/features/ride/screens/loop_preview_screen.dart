import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/map/pasyar_map.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/generated_loop.dart';
import '../loop_stats.dart';
import '../providers/loop_preview_provider.dart';
import '../providers/ride_session_provider.dart';
import '../widgets/home_controls.dart';
import '../widgets/loop_map.dart';

/// Loop preview with Shuffle. Matches design/screenshots/02-loop-preview.png:
/// back button and "HALF-DAY LOOP" pill on top, the loop on the map, and a
/// sheet with stats, the main stop, SHUFFLE and START RIDE.
class LoopPreviewScreen extends StatelessWidget {
  const LoopPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final preview = context.watch<LoopPreviewProvider>();
    final loop = preview.loop;
    final request = preview.request;
    final top = MediaQuery.paddingOf(context).top + PasyarSpacing.floatingTop;

    if (loop == null || request == null) {
      // Nothing generated (e.g. the app was restored here): back to Home.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && context.canPop()) context.pop();
      });
      return const Scaffold(backgroundColor: PasyarColors.mapGround);
    }

    final error = preview.error;
    final notice = preview.loading
        ? const MapNotice.loading(text: 'Finding another loop…')
        : error != null
        ? MapNotice(icon: LucideIcons.circleAlert, text: error.message)
        : loop.warnings.isNotEmpty
        ? MapNotice(
            icon: LucideIcons.triangleAlert,
            text: loop.warnings.join(' '),
          )
        : null;

    return Scaffold(
      backgroundColor: PasyarColors.mapGround,
      body: Stack(
        children: [
          MapUnderSheet(
            map: LoopMap(
              route: loop.route,
              mainStop: preview.mainStop?.location,
              fuel: [for (final f in loop.fuelStops) f.location],
              // Keep the loop clear of the top controls and the sheet edge.
              fitPadding: EdgeInsets.fromLTRB(
                40,
                top + 48 + 32,
                40,
                PasyarRadius.sheet + 40,
              ),
              attributionBottom: PasyarRadius.sheet,
            ),
            sheet: _PreviewSheet(preview: preview, loop: loop),
          ),
          Positioned(
            top: top,
            left: PasyarSpacing.screen,
            right: PasyarSpacing.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    RoundIconButton.floating(
                      icon: LucideIcons.chevronLeft,
                      semanticLabel: 'Back',
                      onPressed: () => context.pop(),
                    ),
                    Flexible(
                      child: FloatingPill(
                        child: Text(
                          preview.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PasyarTextStyles.pillTitle,
                        ),
                      ),
                    ),
                  ],
                ),
                ?notice,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String? get ifNotEmpty => isEmpty ? null : this;
}

Future<void> _startRide(BuildContext context, StopInfo stop) async {
  final preview = context.read<LoopPreviewProvider>();
  await context.read<RideSessionProvider>().start(
    loop: preview.loop!,
    stop: stop,
    request: preview.request!,
  );
  if (context.mounted) context.pushReplacement(Routes.rideSession);
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.preview, required this.loop});

  final LoopPreviewProvider preview;
  final GeneratedLoop loop;

  @override
  Widget build(BuildContext context) {
    final curvy = curvyLevel(loop.curvinessScore);
    final stop = preview.mainStop;
    final bottom = math.max(
      36.0,
      MediaQuery.viewPaddingOf(context).bottom + 20,
    );

    return BottomSheetPanel(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
      children: [
        StatRow(
          children: [
            StatBlock(label: 'Distance', value: formatDistance(loop.distanceM)),
            StatBlock(
              label: 'Ride time',
              value: formatRideTime(loop.durationS),
            ),
            StatBlock(
              label: 'Curvy roads',
              value: curvy.label,
              valueColor: curvy == CurvyLevel.high
                  ? PasyarColors.accentDark
                  : null,
            ),
          ],
        ),
        if (stop != null)
          StopCard(
            overline: 'MAIN STOP · ${stop.kmInLabel}',
            name: stop.title,
            detail: stopDetail(stop, loop.fuelStops).ifNotEmpty,
          ),
        // Ride this loop: the distance includes getting there and back.
        if (loop.approachM > 0)
          Text(
            'Includes ${formatDistance(loop.approachM)} to the loop and '
            'back.',
            style: PasyarTextStyles.body.copyWith(color: PasyarColors.muted),
          ),
        Row(
          spacing: PasyarSpacing.buttonGap,
          children: [
            // Someone else's loop is that loop: nothing to shuffle.
            if (!preview.isRideThisLoop)
              SizedBox(
                width: 132,
                child: SecondaryButton(
                  label: 'SHUFFLE',
                  icon: LucideIcons.shuffle,
                  loading: preview.loading,
                  onPressed: preview.shuffle,
                ),
              ),
            Expanded(
              child: PrimaryButton(
                label: 'START RIDE',
                icon: Icons.play_arrow_rounded,
                // Google Maps navigates; Pasyar tracks the ride (Prompt 10a).
                onPressed: preview.loading || stop == null
                    ? null
                    : () => _startRide(context, stop),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
