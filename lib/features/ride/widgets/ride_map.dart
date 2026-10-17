import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/env.dart';
import '../../../core/map/map_markers.dart';
import '../../../core/theme/pasyar_theme.dart';

/// Whole Philippines, shown until the first GPS fix.
const _philippines = LatLng(12.3, 122.6);
const _countryZoom = 5.5;
const _riderZoom = 15.0;

/// Full-screen map with the rider dot. Centers on the rider at the first fix;
/// after that the rider can pan freely. [attributionBottom] lifts the
/// attribution above whatever covers the bottom of the map.
class RideMap extends StatefulWidget {
  const RideMap({super.key, required this.rider, this.attributionBottom = 0});

  final LatLng? rider;
  final double attributionBottom;

  @override
  State<RideMap> createState() => _RideMapState();
}

class _RideMapState extends State<RideMap> {
  final _controller = MapController();
  bool _ready = false;
  late bool _centered = widget.rider != null;

  @override
  void didUpdateWidget(RideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    _centerOnFirstFix();
  }

  void _centerOnFirstFix() {
    final rider = widget.rider;
    if (_centered || !_ready || rider == null) return;
    _centered = true;
    _controller.move(rider, _riderZoom);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rider = widget.rider;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: rider ?? _philippines,
        initialZoom: rider == null ? _countryZoom : _riderZoom,
        minZoom: 4,
        maxZoom: 18,
        backgroundColor: PasyarColors.mapGround,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _ready = true;
          _centerOnFirstFix();
        },
      ),
      children: [
        // Tests and CI build without a tile URL; the map stays plain.
        if (Env.mapTileUrl.isNotEmpty)
          TileLayer(
            urlTemplate: Env.mapTileUrl,
            additionalOptions: const {'key': Env.mapTileKey},
            // MapTiler raster tiles are 512 px.
            tileDimension: 512,
            zoomOffset: -1,
            userAgentPackageName: Env.appId,
          ),
        if (rider != null) MarkerLayer(markers: [PasyarMarkers.rider(rider)]),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: 8,
              bottom: widget.attributionBottom + 4,
            ),
            child: const MapAttribution(),
          ),
        ),
      ],
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
            color: PasyarColors.card.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '© MapTiler © OpenStreetMap contributors',
            style: PasyarTextStyles.label.copyWith(fontSize: 11),
          ),
        ),
      ),
    );
  }
}
