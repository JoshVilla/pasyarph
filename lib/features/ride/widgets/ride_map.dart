import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/map_markers.dart';
import '../../../core/map/pasyar_map.dart';
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
        ?pasyarTileLayer(),
        if (rider != null) MarkerLayer(markers: [PasyarMarkers.rider(rider)]),
        MapAttributionLayer(bottom: widget.attributionBottom),
      ],
    );
  }
}
