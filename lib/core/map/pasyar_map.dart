import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../env.dart';
import '../theme/pasyar_theme.dart';
import '../widgets/collapsible_sheet.dart';

/// MapTiler raster tiles from [Env]. Null when no tile URL is configured
/// (tests and CI), so the map stays plain `mapGround`.
Widget? pasyarTileLayer() {
  if (Env.mapTileUrl.isEmpty) return null;
  return TileLayer(
    urlTemplate: Env.mapTileUrl,
    additionalOptions: const {'key': Env.mapTileKey},
    // MapTiler raster tiles are 512 px.
    tileDimension: 512,
    zoomOffset: -1,
    userAgentPackageName: Env.appId,
  );
}

/// [MapAttribution] in the bottom-right corner, lifted [bottom] px above
/// whatever covers the bottom of the map. Add as the last map child.
class MapAttributionLayer extends StatelessWidget {
  const MapAttributionLayer({super.key, this.bottom = 0});

  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: EdgeInsets.only(right: 8, bottom: bottom + 4),
        child: const MapAttribution(),
      ),
    );
  }
}

/// Required credit for MapTiler and OpenStreetMap. Tapping opens MapTiler's
/// copyright page, which links to OpenStreetMap's.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  static final _copyright = Uri.https('www.maptiler.com', '/copyright/');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      label: 'Map data credits',
      child: GestureDetector(
        onTap: () => launchUrl(_copyright),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: PasyarColors.of(context).card.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '© MapTiler © OpenStreetMap contributors',
            style: PasyarTextStyles.of(context).label.copyWith(fontSize: 11),
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet at its natural height with a map filling the rest. The
/// map runs [overlap] px under the sheet's rounded corners, so whatever is
/// centered on the map is centered in the part you can see. With
/// [collapsed] above 0 the sheet slides down (to [peek] px at 1) and the
/// map grows into the space (see CollapsibleSheet).
class MapUnderSheet extends StatelessWidget {
  const MapUnderSheet({
    super.key,
    required this.map,
    required this.sheet,
    this.overlap = PasyarRadius.sheet,
    this.collapsed = 0,
    this.peek = sheetPeekHeight,
  });

  final Widget map;
  final Widget sheet;
  final double overlap;
  final double collapsed;
  final double peek;

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: _MapUnderSheetLayout(overlap, collapsed, peek),
      children: [
        LayoutId(id: _Slot.map, child: map),
        LayoutId(id: _Slot.sheet, child: sheet),
      ],
    );
  }
}

enum _Slot { map, sheet }

class _MapUnderSheetLayout extends MultiChildLayoutDelegate {
  _MapUnderSheetLayout(this.overlap, this.collapsed, this.peek);

  final double overlap;
  final double collapsed;
  final double peek;

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
    // How far the sheet has slid down; what's still showing of it.
    final down = collapsed * (sheet.height - peek).clamp(0.0, sheet.height);
    final showing = sheet.height - down;
    positionChild(_Slot.sheet, Offset(0, size.height - showing));

    final mapHeight = (size.height - showing + overlap).clamp(0.0, size.height);
    layoutChild(_Slot.map, BoxConstraints.tight(Size(size.width, mapHeight)));
    positionChild(_Slot.map, Offset.zero);
  }

  @override
  bool shouldRelayout(_MapUnderSheetLayout oldDelegate) =>
      oldDelegate.overlap != overlap ||
      oldDelegate.collapsed != collapsed ||
      oldDelegate.peek != peek;
}
