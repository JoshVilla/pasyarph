import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/ride_options_provider.dart';
import '../widgets/home_controls.dart';
import '../widgets/ride_map.dart';

/// Ride tab (Home). Matches design/screenshots/01-home.png: full-screen map,
/// "Starting from" pill and profile button on top, "WHERE TO TODAY?" sheet
/// at the bottom. Expects a [LocationProvider] above it.
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
  @override
  void initState() {
    super.initState();
    context.read<LocationProvider>().start();
  }

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationProvider>();
    final options = context.watch<RideOptionsProvider>();
    final status = location.status;
    final showBanner =
        status != LocationStatus.on && status != LocationStatus.checking;

    return Scaffold(
      backgroundColor: PasyarColors.mapGround,
      body: Stack(
        children: [
          CustomMultiChildLayout(
            delegate: _MapUnderSheetLayout(),
            children: [
              LayoutId(
                id: _Slot.map,
                child: RideMap(
                  rider: location.position,
                  attributionBottom: PasyarRadius.sheet,
                ),
              ),
              LayoutId(
                id: _Slot.sheet,
                child: WhereToSheet(
                  options: options,
                  // Generating comes with the next prompt.
                  onGenerate: location.hasFix ? () {} : null,
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + PasyarSpacing.floatingTop,
            left: PasyarSpacing.screen,
            right: PasyarSpacing.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    const Expanded(child: StartingFromPill()),
                    RoundIconButton.floating(
                      icon: LucideIcons.user,
                      semanticLabel: 'Profile',
                      onPressed: () => context.go(Routes.me),
                    ),
                  ],
                ),
                if (showBanner)
                  LocationOffBanner(status: status, onPressed: location.fix),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _Slot { map, sheet }

/// Sheet at the bottom at its natural height; the map fills the rest and
/// runs under the sheet's rounded corners, so the rider dot is centered in
/// the part of the map you can see.
class _MapUnderSheetLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final sheet = layoutChild(
      _Slot.sheet,
      BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
        maxHeight: size.height,
      ),
    );
    positionChild(_Slot.sheet, Offset(0, size.height - sheet.height));

    final mapHeight = (size.height - sheet.height + PasyarRadius.sheet).clamp(
      0.0,
      size.height,
    );
    layoutChild(_Slot.map, BoxConstraints.tight(Size(size.width, mapHeight)));
    positionChild(_Slot.map, Offset.zero);
  }

  @override
  bool shouldRelayout(_MapUnderSheetLayout oldDelegate) => false;
}
