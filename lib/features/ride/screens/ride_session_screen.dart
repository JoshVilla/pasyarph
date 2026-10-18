import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/map/pasyar_map.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../loop_stats.dart';
import '../providers/ride_session_provider.dart';
import '../widgets/home_controls.dart';
import '../widgets/loop_map.dart';

/// A ride in progress. Google Maps does the turn-by-turn; this screen is
/// what the rider sees when they come back to Pasyar: the loop with the
/// ridden part grey, distance and time, the main stop, and buttons to go
/// back to Google Maps or end the ride. No mockup: built from DESIGN.md
/// components (same layout as the loop preview).
class RideSessionScreen extends StatefulWidget {
  const RideSessionScreen({super.key});

  @override
  State<RideSessionScreen> createState() => _RideSessionScreenState();
}

class _RideSessionScreenState extends State<RideSessionScreen> {
  /// Elapsed time ticks even when no GPS fix arrives.
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _done() {
    context.read<RideSessionProvider>().close();
    if (context.canPop()) context.pop();
  }

  Future<void> _confirmEnd() async {
    final end = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BottomSheetPanel(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          math.max(20, MediaQuery.viewPaddingOf(context).bottom + 20),
        ),
        children: [
          Text('END THIS RIDE?', style: PasyarTextStyles.screenTitle(30)),
          Text(
            "We'll save what you've ridden so far.",
            style: PasyarTextStyles.body.copyWith(color: PasyarColors.muted),
          ),
          PrimaryButton(
            label: 'END RIDE',
            onPressed: () => Navigator.pop(context, true),
          ),
          SecondaryButton(
            label: 'KEEP RIDING',
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (end == true && mounted) {
      await context.read<RideSessionProvider>().end();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = context.watch<RideSessionProvider>();
    final loop = ride.loop;
    final stop = ride.stop;
    final top = MediaQuery.paddingOf(context).top + PasyarSpacing.floatingTop;

    if (loop == null || stop == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && context.canPop()) context.pop();
      });
      return const Scaffold(backgroundColor: PasyarColors.mapGround);
    }

    final finished = ride.phase == RidePhase.finished;
    final split = ride.split;
    final notice = finished
        ? null
        : !ride.mapsOpened
        ? const MapNotice(
            icon: LucideIcons.circleAlert,
            text:
                "Couldn't open Google Maps. Install it, then tap GOOGLE MAPS.",
          )
        : ride.reachedStop
        ? MapNotice(
            icon: LucideIcons.flag,
            text:
                'You made it to ${stop.title}. Photos come in the next update.',
          )
        : null;

    return PopScope(
      // While riding, Back would leave the ride without ending it.
      canPop: !ride.active,
      child: Scaffold(
        backgroundColor: PasyarColors.mapGround,
        body: Stack(
          children: [
            MapUnderSheet(
              map: LoopMap(
                route: loop.route,
                ahead: split?.ahead,
                ridden: split?.behind ?? const [],
                rider: ride.position,
                mainStop: stop.location,
                fuel: [for (final f in loop.fuelStops) f.location],
                fitPadding: EdgeInsets.fromLTRB(
                  40,
                  top + 48 + 32,
                  40,
                  PasyarRadius.sheet + 40,
                ),
                attributionBottom: PasyarRadius.sheet,
              ),
              sheet: finished
                  ? _SummarySheet(ride: ride, onDone: _done)
                  : _RidingSheet(ride: ride, onEnd: _confirmEnd),
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
                    children: [
                      FloatingPill(
                        child: Text(
                          finished ? 'LOOP DONE' : 'RIDE IN PROGRESS',
                          style: PasyarTextStyles.pillTitle,
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
      ),
    );
  }
}

class _RidingSheet extends StatelessWidget {
  const _RidingSheet({required this.ride, required this.onEnd});

  final RideSessionProvider ride;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final stop = ride.stop!;
    final toStop = ride.toStopM;
    final bottom = math.max(
      36.0,
      MediaQuery.viewPaddingOf(context).bottom + 20,
    );
    return BottomSheetPanel(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
      children: [
        StatRow(
          children: [
            StatBlock(
              label: 'Ridden',
              value: formatDistance(ride.riddenM.round()),
            ),
            StatBlock(
              label: 'Time',
              value: formatRideTime(ride.elapsed.inSeconds),
            ),
            StatBlock(label: 'Speed', value: '${ride.speedKmh.round()} km/h'),
          ],
        ),
        StopCard(
          overline: toStop == null
              ? 'MAIN STOP · REACHED'
              : 'MAIN STOP · ${formatDistance(toStop.round()).toUpperCase()} TO GO',
          name: stop.title,
          detail: stopDetail(stop, ride.loop!.fuelStops).ifNotEmpty,
        ),
        Row(
          spacing: PasyarSpacing.buttonGap,
          children: [
            SizedBox(
              width: 132,
              child: SecondaryButton(label: 'END RIDE', onPressed: onEnd),
            ),
            Expanded(
              child: PrimaryButton(
                label: 'GOOGLE MAPS',
                icon: LucideIcons.navigation,
                onPressed: ride.openMaps,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummarySheet extends StatelessWidget {
  const _SummarySheet({required this.ride, required this.onDone});

  final RideSessionProvider ride;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final summary = ride.summary;
    final bottom = math.max(
      36.0,
      MediaQuery.viewPaddingOf(context).bottom + 20,
    );
    return BottomSheetPanel(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
      children: [
        StatRow(
          children: [
            StatBlock(
              label: 'Ridden',
              value: formatDistance((summary?.riddenM ?? 0).round()),
            ),
            StatBlock(
              label: 'Time',
              value: formatRideTime(summary?.duration.inSeconds ?? 0),
            ),
            StatBlock(
              label: 'Main stop',
              value: (summary?.reachedStop ?? false) ? 'Yes' : 'No',
              valueColor: (summary?.reachedStop ?? false)
                  ? PasyarColors.accentDark
                  : null,
            ),
          ],
        ),
        PrimaryButton(label: 'DONE', onPressed: onDone),
      ],
    );
  }
}

extension on String {
  String? get ifNotEmpty => isEmpty ? null : this;
}
