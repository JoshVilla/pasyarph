import 'dart:math' as math;

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
///
/// With [reachM], a ring around the rider shows roughly how far the chosen
/// loop goes, and the map frames it whenever it changes.
class RideMap extends StatefulWidget {
  const RideMap({
    super.key,
    required this.rider,
    this.attributionBottom = 0,
    this.reachM,
    this.topInset = 0,
  });

  final LatLng? rider;
  final double attributionBottom;

  /// Radius of the reach ring in meters; null hides it.
  final double? reachM;

  /// Kept clear when framing the ring (the controls floating on top).
  final double topInset;

  /// A loop of [km] winds around a rough circle: its radius.
  static double reachFor(int km) => km * 1000 / (2 * math.pi);

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
    if (_centered && oldWidget.reachM != widget.reachM) _frameReach();
    _centerOnFirstFix();
  }

  void _centerOnFirstFix() {
    final rider = widget.rider;
    if (_centered || !_ready || rider == null) return;
    _centered = true;
    if (widget.reachM != null) {
      _frameReach();
    } else {
      _controller.move(rider, _riderZoom);
    }
  }

  /// The reach ring between the floating controls and the sheet.
  CameraFit? _reachFit() {
    final rider = widget.rider;
    final reach = widget.reachM;
    if (rider == null || reach == null) return null;
    const d = Distance();
    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([
        for (final bearing in const [0.0, 90.0, 180.0, 270.0])
          d.offset(rider, reach, bearing),
      ]),
      padding: EdgeInsets.fromLTRB(
        24,
        widget.topInset + 24,
        24,
        widget.attributionBottom + 24,
      ),
    );
  }

  /// Fits the reach ring after a change (a new duration, the first fix).
  void _frameReach() {
    final fit = _reachFit();
    if (_ready && fit != null) _controller.fitCamera(fit);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rider = widget.rider;
    final reach = widget.reachM;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: rider ?? _philippines,
        initialZoom: rider == null ? _countryZoom : _riderZoom,
        // Known position on open: start on the ring (moving the camera
        // in onMapReady leaves the tiles unloaded).
        initialCameraFit: _reachFit(),
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
        if (rider != null && reach != null)
          // The ring grows or shrinks to a new duration as the headline
          // changes (instantly with reduced motion).
          TweenAnimationBuilder<double>(
            tween: Tween(end: reach),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (context, r, _) => Stack(
              children: [
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: rider,
                      radius: r,
                      useRadiusInMeter: true,
                      color: PasyarColors.accent.withValues(alpha: 0.06),
                      borderColor: PasyarColors.accent.withValues(alpha: 0.75),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: const Distance().offset(rider, r, 0),
                      width: 220,
                      height: 28,
                      child: Center(child: _ReachLabel(km: reach / 1000)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // The loop starts here: the same S as on the Create map.
        if (rider != null)
          MarkerLayer(markers: [PasyarMarkers.loopStart(rider)]),
        MapAttributionLayer(bottom: widget.attributionBottom),
      ],
    );
  }
}

/// "~19 km out" on the top of the reach ring.
class _ReachLabel extends StatelessWidget {
  const _ReachLabel({required this.km});

  final double km;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PasyarColors.card,
        borderRadius: BorderRadius.circular(PasyarRadius.pill),
        border: Border.all(color: PasyarColors.accent, width: 1.5),
      ),
      child: Text(
        'Loop reaches ~${km.round()} km out',
        maxLines: 1,
        style: PasyarTextStyles.label.copyWith(
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: PasyarColors.accentDark,
        ),
      ),
    );
  }
}
