import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/map_markers.dart';
import '../../../core/map/pasyar_map.dart';
import '../../../core/map/route_style.dart';
import '../../../core/theme/pasyar_theme.dart';

/// A loop on the map: orange route on a white casing, start dot, main stop
/// flag and fuel stations. Fits the whole loop inside [fitPadding], and
/// refits when the route changes (Shuffle).
class LoopMap extends StatefulWidget {
  const LoopMap({
    super.key,
    required this.route,
    required this.mainStop,
    this.fuel = const [],
    this.fitPadding = const EdgeInsets.all(40),
    this.attributionBottom = 0,
  });

  final List<LatLng> route;
  final LatLng? mainStop;

  /// Fuel stations, drawn under the main stop and start markers.
  final List<LatLng> fuel;
  final EdgeInsets fitPadding;
  final double attributionBottom;

  @override
  State<LoopMap> createState() => _LoopMapState();
}

class _LoopMapState extends State<LoopMap> {
  final _controller = MapController();
  bool _ready = false;

  CameraFit get _fit => CameraFit.coordinates(
    coordinates: widget.route,
    padding: widget.fitPadding,
  );

  @override
  void didUpdateWidget(LoopMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && !identical(oldWidget.route, widget.route)) {
      _controller.fitCamera(_fit);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainStop = widget.mainStop;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCameraFit: _fit,
        minZoom: 4,
        maxZoom: 18,
        backgroundColor: PasyarColors.mapGround,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _ready = true,
      ),
      children: [
        ?pasyarTileLayer(),
        PolylineLayer(polylines: routePolylines(route: widget.route)),
        MarkerLayer(
          markers: [
            for (final f in widget.fuel) PasyarMarkers.fuel(f),
            if (mainStop != null) PasyarMarkers.mainStop(mainStop),
            PasyarMarkers.rider(widget.route.first, halo: false),
          ],
        ),
        MapAttributionLayer(bottom: widget.attributionBottom),
      ],
    );
  }
}
