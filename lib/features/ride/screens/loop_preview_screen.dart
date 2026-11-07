import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/map/map_legend.dart';
import '../../../core/map/pasyar_map.dart';
import '../../../core/router.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/generated_loop.dart';
import '../loop_stats.dart';
import '../providers/loop_preview_provider.dart';
import '../providers/ride_session_provider.dart';
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
        if (context.mounted) _back(context);
      });
      return Scaffold(backgroundColor: PasyarColors.of(context).mapGround);
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
      backgroundColor: PasyarColors.of(context).mapGround,
      body: Stack(
        children: [
          // Drag the sheet down to see more of the loop.
          CollapsibleSheet(
            builder: (context, collapsed, wrapSheet) => MapUnderSheet(
              collapsed: collapsed,
              map: Stack(
                children: [
                  Positioned.fill(
                    child: LoopMap(
                      route: loop.route,
                      mainStop: preview.mainStop?.location,
                      fuel: [for (final f in loop.fuelStops) f.location],
                      overnights: [for (final n in loop.overnights) n.location],
                      // Keep the loop clear of the top controls and the key
                      // above the sheet edge.
                      fitPadding: EdgeInsets.fromLTRB(
                        40,
                        top + 48 + 32,
                        40,
                        PasyarRadius.sheet + 40 + _keyHeight,
                      ),
                      attributionBottom: PasyarRadius.sheet,
                    ),
                  ),
                  Positioned(
                    left: PasyarSpacing.screen,
                    right: PasyarSpacing.screen,
                    bottom: PasyarRadius.sheet + 32,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: _PreviewKey(
                        items: [
                          MapKeyItem.startS,
                          if (preview.mainStop != null) MapKeyItem.mainStop,
                          if (loop.fuelStops.isNotEmpty) MapKeyItem.fuel,
                          if (loop.overnights.isNotEmpty) MapKeyItem.overnights,
                          MapKeyItem.direction,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              sheet: wrapSheet(
                MotionChange(
                  value: loop,
                  child: _PreviewSheet(preview: preview, loop: loop),
                ),
              ),
            ),
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
                      onPressed: () => _back(context),
                    ),
                    Flexible(
                      child: FloatingPill(
                        child: Text(
                          preview.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PasyarTextStyles.of(context).pillTitle,
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

/// Room kept under the loop for the map key strip.
const _keyHeight = 64.0;

/// The preview map's key: a strip that starts open; a tap folds it to a
/// chip.
class _PreviewKey extends StatefulWidget {
  const _PreviewKey({required this.items});

  final List<MapKeyItem> items;

  @override
  State<_PreviewKey> createState() => _PreviewKeyState();
}

class _PreviewKeyState extends State<_PreviewKey> {
  bool _open = true;

  @override
  Widget build(BuildContext context) => MapLegend(
    items: widget.items,
    row: true,
    open: _open,
    onToggle: () => setState(() => _open = !_open),
  );
}

/// Opened from a share link, the preview is the only screen: back goes Home.
void _back(BuildContext context) =>
    context.canPop() ? context.pop() : context.go(Routes.ride);

/// Multi-day loops: the suggested overnight towns, numbered as on the map.
class _Overnights extends StatelessWidget {
  const _Overnights(this.nights);

  final List<Overnight> nights;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: PasyarColors.of(context).ground,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Text('OVERNIGHT STOPS', style: PasyarTextStyles.of(context).overline),
          for (final (i, n) in nights.indexed)
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    'Night ${i + 1} · ${n.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PasyarTextStyles.of(
                      context,
                    ).bodySmall.copyWith(height: 1.3),
                  ),
                ),
                Text(
                  '${n.kmIntoRoute} km in',
                  style: PasyarTextStyles.of(
                    context,
                  ).label.copyWith(height: 1.3),
                ),
              ],
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
  // The first ride on this phone starts with the safety reminders.
  if (!context.read<AppSettings>().firstRideSafetySeen) {
    final ready = await context.push<bool>(Routes.rideSafety);
    if (ready != true || !context.mounted) return;
  }
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
                  ? PasyarColors.of(context).accentDark
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
        if (loop.overnights.isNotEmpty) _Overnights(loop.overnights),
        // Ride this loop: the distance includes getting there and back.
        if (loop.approachM > 0)
          Text(
            'Includes ${formatDistance(loop.approachM)} to the loop and '
            'back.',
            style: PasyarTextStyles.of(
              context,
            ).body.copyWith(color: PasyarColors.of(context).muted),
          ),
        Row(
          spacing: PasyarSpacing.buttonGap,
          children: [
            // Someone else's loop is that loop: nothing to shuffle.
            if (!preview.isRideThisLoop)
              SizedBox(
                width: 132,
                child: SecondaryButton(
                  label: 'Shuffle',
                  icon: LucideIcons.shuffle,
                  loading: preview.loading,
                  onPressed: preview.shuffle,
                ),
              ),
            Expanded(
              child: PrimaryButton(
                label: 'Start ride',
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
