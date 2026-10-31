import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/map/pasyar_map.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/loop_preview_provider.dart';
import '../providers/ride_options_provider.dart';
import '../providers/ride_session_provider.dart';
import '../widgets/home_controls.dart';
import '../widgets/ride_map.dart';

/// Ride tab (Home): full-screen map with a ring showing roughly how far the
/// chosen loop reaches, the "Starting from" pill on top, and the sheet that
/// reads as one sentence ("I'VE GOT ABOUT 4 HRS") above GENERATE LOOP.
/// Location trouble and Generate errors show in the sheet, by the button.
/// Expects [LocationProvider] and [LoopPreviewProvider] above it.
class RideScreen extends StatelessWidget {
  const RideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RideOptionsProvider(),
      child: const _RideHome(),
    );
  }
}

class _RideHome extends StatefulWidget {
  const _RideHome();

  @override
  State<_RideHome> createState() => _RideHomeState();
}

class _RideHomeState extends State<_RideHome> {
  /// Errors from Generate show here only, not after returning from Preview.
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    context.read<LocationProvider>().start();
  }

  Future<void> _generate() async {
    final position = context.read<LocationProvider>().position;
    if (position == null) return;
    final options = context.read<RideOptionsProvider>();
    setState(() => _showError = true);
    final ready = await context.read<LoopPreviewProvider>().generate(
      LoopRequest(
        start: position,
        duration: options.duration,
        avoidHighways: options.avoidHighways,
        avoidUnpaved: options.avoidUnpaved,
        days: options.days,
      ),
    );
    if (!mounted) return;
    if (ready) {
      setState(() => _showError = false);
      context.push(Routes.loopPreview);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final options = context.watch<RideOptionsProvider>();
    final preview = context.watch<LoopPreviewProvider>();
    final ride = context.watch<RideSessionProvider>();
    final status = location.status;
    final showBanner =
        status != LocationStatus.on && status != LocationStatus.checking;
    final generating = preview.loading && preview.loop == null;
    final error = _showError ? preview.error : null;

    final reachKm = options.duration.targetKm;
    final top = MediaQuery.paddingOf(context).top + PasyarSpacing.floatingTop;
    final Widget? notice = showBanner
        ? LocationOffBanner(status: status, onPressed: location.fix)
        : error != null
        ? SheetError(error.message)
        : status == LocationStatus.on && !location.hasFix
        ? const SheetWaiting()
        : null;

    return Scaffold(
      backgroundColor: PasyarColors.of(context).mapGround,
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, box) => MapUnderSheet(
              map: RideMap(
                rider: location.position,
                attributionBottom: PasyarRadius.sheet,
                reachM: reachKm == null ? null : RideMap.reachFor(reachKm),
                // The pill and any notice under it.
                topInset: top + 48 + (ride.active || generating ? 60 : 0),
              ),
              sheet: WhereToSheet(
                options: options,
                onDiscover: () => context.push(Routes.discover),
                generating: generating,
                notice: notice,
                onGenerate: location.hasFix ? _generate : null,
                // Never up under the pill: some map always shows.
                maxHeight: box.maxHeight - (top + 48 + 48),
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
                StartingFromPill(on: !showBanner),
                if (ride.active)
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: () => context.push(Routes.rideSession),
                      child: const MapNotice(
                        icon: LucideIcons.navigation,
                        text: 'Ride in progress. Tap to open it.',
                      ),
                    ),
                  )
                else if (generating)
                  const MapNotice.loading(text: 'Building your loop…'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
