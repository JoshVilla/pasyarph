import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/map/map_markers.dart';
import '../../../core/map/pasyar_map.dart';
import '../../../core/map/route_style.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../loop_builder.dart';

/// Where the map looks before the first location fix: the Philippines.
const _philippines = LatLng(12.88, 121.77);

/// The Create map: tap to add a point; tap a point to make it the main
/// stop, hold it to remove it, drag it to move it. Draws routed legs as the
/// route line and the closing leg (and legs still routing) dashed.
class CreateLoopMap extends StatefulWidget {
  const CreateLoopMap({
    super.key,
    required this.start,
    required this.points,
    required this.mainStop,
    required this.shape,
    required this.onAdd,
    required this.onMainStop,
    required this.onRemove,
    required this.onDrag,
    required this.onDragEnd,
    this.attributionBottom = 0,
  });

  final LatLng? start;
  final List<LatLng> points;

  /// Index into [points] drawn with the main stop flag.
  final int? mainStop;
  final LoopShape shape;
  final ValueChanged<LatLng> onAdd;
  final ValueChanged<int> onMainStop;
  final ValueChanged<int> onRemove;
  final void Function(int index, LatLng to) onDrag;
  final VoidCallback onDragEnd;
  final double attributionBottom;

  @override
  State<CreateLoopMap> createState() => _CreateLoopMapState();
}

class _CreateLoopMapState extends State<CreateLoopMap> {
  final _controller = MapController();
  final _key = GlobalKey();
  bool _ready = false;

  @override
  void didUpdateWidget(CreateLoopMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final start = widget.start;
    if (_ready && oldWidget.start == null && start != null) {
      _controller.move(start, 13);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opening on a loop in progress shows all of it; a new one starts
  /// zoomed in on S.
  MapOptions _options() {
    final stops = [?widget.start, ...widget.points];
    const base = InteractionOptions(
      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
    );
    void onTap(TapPosition _, LatLng at) => widget.onAdd(at);
    void onReady() => _ready = true;
    if (stops.length > 1) {
      return MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: stops,
          // Clear of the top controls, as framed in the mockup.
          padding: const EdgeInsets.fromLTRB(60, 140, 70, 96),
        ),
        minZoom: 4,
        maxZoom: 18,
        backgroundColor: PasyarColors.mapGround,
        interactionOptions: base,
        onTap: onTap,
        onMapReady: onReady,
      );
    }
    return MapOptions(
      initialCenter: widget.start ?? _philippines,
      initialZoom: widget.start == null ? 6 : 13,
      minZoom: 4,
      maxZoom: 18,
      backgroundColor: PasyarColors.mapGround,
      interactionOptions: base,
      onTap: onTap,
      onMapReady: onReady,
    );
  }

  void _drag(int index, Offset global) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final at = _controller.camera.screenOffsetToLatLng(
      box.globalToLocal(global),
    );
    widget.onDrag(index, at);
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.start;
    final shape = widget.shape;
    return FlutterMap(
      key: _key,
      mapController: _controller,
      options: _options(),
      children: [
        ?pasyarTileLayer(),
        PolylineLayer(
          polylines: [
            for (final line in shape.solid) ...routePolylines(route: line),
            for (final line in shape.dashed) ...routePolylines(closing: line),
          ],
        ),
        MarkerLayer(
          markers: [
            for (var i = 0; i < widget.points.length; i++)
              Marker(
                point: widget.points[i],
                width: _PointHandle.size,
                height: _PointHandle.size,
                child: _PointHandle(
                  number: i + 1,
                  isMainStop: i == widget.mainStop,
                  onTap: () => widget.onMainStop(i),
                  onLongPress: () => widget.onRemove(i),
                  onDrag: (global) => _drag(i, global),
                  onDragEnd: widget.onDragEnd,
                ),
              ),
            if (start != null) PasyarMarkers.loopStart(start),
          ],
        ),
        MapAttributionLayer(bottom: widget.attributionBottom),
      ],
    );
  }
}

/// A numbered point (or the main stop flag) with a glove-sized touch area.
class _PointHandle extends StatelessWidget {
  const _PointHandle({
    required this.number,
    required this.isMainStop,
    required this.onTap,
    required this.onLongPress,
    required this.onDrag,
    required this.onDragEnd,
  });

  static const size = 48.0;

  final int number;
  final bool isMainStop;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isMainStop ? 'Point $number, main stop' : 'Point $number',
      hint: 'Tap for the main stop, hold to remove',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        onPanUpdate: (d) => onDrag(d.globalPosition),
        onPanEnd: (_) => onDragEnd(),
        child: Center(
          child: isMainStop
              ? const MainStopMarker(radius: 15)
              : LoopPointMarker(label: '$number'),
        ),
      ),
    );
  }
}
