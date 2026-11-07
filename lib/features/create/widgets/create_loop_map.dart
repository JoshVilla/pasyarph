import 'package:flutter/material.dart';
import '../../../core/widgets/motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/map/map_markers.dart';
import '../../../core/map/route_arrows.dart';
import '../../../core/map/pasyar_map.dart';
import '../../../core/map/route_style.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../loop_builder.dart';

/// Where the map looks before the first location fix: the Philippines.
const _philippines = LatLng(12.88, 121.77);

/// The Create map: tap to add a point; tap a point to select it, which
/// floats MAIN STOP · REMOVE above it ([onSelect]); hold a point to remove
/// it at once; drag it to move it. While a point is selected, a tap on the
/// map only closes its actions. Draws routed legs as the route line and the
/// closing leg (and legs still routing) dashed.
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
    required this.onSelect,
    this.selected,
    this.attributionBottom = 0,
    this.topInset = 0,
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

  /// The tapped point (index into [points]) showing its actions, or null.
  final int? selected;
  final ValueChanged<int?> onSelect;
  final double attributionBottom;

  /// Height of the controls floating on top; a point's actions open below
  /// it rather than under them.
  final double topInset;

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
    void onTap(TapPosition _, LatLng at) =>
        widget.selected != null ? widget.onSelect(null) : widget.onAdd(at);
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
        backgroundColor: PasyarColors.of(context).mapGround,
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
      backgroundColor: PasyarColors.of(context).mapGround,
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
    final selected = widget.selected;
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
        // Which way the loop goes, S → 1 → 2 → … → S.
        RouteArrowsLayer(routes: shape.solid),
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
                  selected: i == selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSelect(i == selected ? null : i);
                  },
                  onLongPress: () => widget.onRemove(i),
                  onDrag: (global) => _drag(i, global),
                  onDragEnd: widget.onDragEnd,
                ),
              ),
            if (start != null) PasyarMarkers.loopStart(start),
          ],
        ),
        if (selected != null && selected < widget.points.length)
          _PointActionsLayer(
            point: widget.points[selected],
            topInset: widget.topInset,
            actions: PointActions(
              number: selected + 1,
              isMainStop: selected == widget.mainStop,
              onMainStop: () {
                widget.onMainStop(selected);
                widget.onSelect(null);
              },
              onRemove: () {
                widget.onRemove(selected);
                widget.onSelect(null);
              },
            ),
          ),
        MapAttributionLayer(bottom: widget.attributionBottom),
      ],
    );
  }
}

/// The main stop flag keeping its place in the order: a small number badge
/// on its corner, so the points still read 1, 2, 3, 4.
class _NumberedFlag extends StatelessWidget {
  const _NumberedFlag({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const MainStopMarker(radius: 15),
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PasyarColors.of(context).accent,
              shape: BoxShape.circle,
              border: Border.all(
                color: PasyarColors.of(context).card,
                width: 2,
              ),
            ),
            child: Text(
              '$number',
              style: PasyarTextStyles.of(context).label.copyWith(
                fontSize: 10,
                height: 1,
                fontWeight: FontWeight.w700,
                color: PasyarColors.of(context).card,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Floats [actions] above [point], or below it when the controls on top of
/// the map would cover them. Rebuilds as the map moves.
class _PointActionsLayer extends StatelessWidget {
  const _PointActionsLayer({
    required this.point,
    required this.topInset,
    required this.actions,
  });

  final LatLng point;
  final double topInset;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final y = MapCamera.of(context).latLngToScreenOffset(point).dy;
    final above = y - PointActions.height - PointActions.lift > topInset;
    return MarkerLayer(
      markers: [
        Marker(
          point: point,
          width: PointActions.width,
          height: PointActions.height + PointActions.lift,
          alignment: above ? Alignment.topCenter : Alignment.bottomCenter,
          child: Align(
            alignment: above ? Alignment.topCenter : Alignment.bottomCenter,
            // Large system text shrinks the card rather than clip it.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.65, end: 1),
              duration: PasyarMotion.duration(
                context,
                const Duration(milliseconds: 120),
              ),
              curve: Curves.easeOutCubic,
              child: FittedBox(fit: BoxFit.scaleDown, child: actions),
              builder: (context, opacity, child) => Opacity(
                opacity: opacity,
                alwaysIncludeSemantics: true,
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A numbered point (or the main stop flag) with a glove-sized touch area.
class _PointHandle extends StatelessWidget {
  const _PointHandle({
    required this.number,
    required this.isMainStop,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onDrag,
    required this.onDragEnd,
  });

  static const size = 48.0;

  final int number;
  final bool isMainStop;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isMainStop ? 'Point $number, main stop' : 'Point $number',
      hint: 'Tap for main stop or remove, hold to remove',
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        onPanUpdate: (d) => onDrag(d.globalPosition),
        onPanEnd: (_) => onDragEnd(),
        child: Center(
          child: DecoratedBox(
            // A soft ring marks the point whose actions are open.
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: PasyarColors.of(context).accentTint,
                        spreadRadius: 6,
                      ),
                    ]
                  : null,
            ),
            child: isMainStop
                ? _NumberedFlag(number: number)
                : LoopPointMarker(label: '$number'),
          ),
        ),
      ),
    );
  }
}

/// The card that floats above a tapped point: MAIN STOP · REMOVE, each a
/// glove-sized button.
class PointActions extends StatelessWidget {
  const PointActions({
    super.key,
    required this.number,
    required this.isMainStop,
    required this.onMainStop,
    required this.onRemove,
  });

  static const width = 248.0;
  static const height = 60.0;

  /// Room between the card and the point it belongs to.
  static const lift = 34.0;

  final int number;
  final bool isMainStop;
  final VoidCallback onMainStop;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Point $number actions',
      child: Container(
        height: height,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: PasyarColors.of(context).card,
          borderRadius: BorderRadius.circular(PasyarRadius.panel),
          boxShadow: PasyarShadows.floating,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            // Each action fills the card's 48 px inner height (gloves).
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              _PointAction(
                icon: isMainStop ? LucideIcons.circleCheck : LucideIcons.flag,
                label: 'MAIN STOP',
                filled: true,
                onTap: isMainStop ? null : onMainStop,
              ),
              _PointAction(
                icon: LucideIcons.trash2,
                label: 'REMOVE',
                onTap: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointAction extends StatelessWidget {
  const _PointAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final color = filled
        ? PasyarColors.of(context).accentDark
        : PasyarColors.of(context).ink;
    return Material(
      color: filled
          ? PasyarColors.of(context).accentTint
          : PasyarColors.of(context).ground,
      borderRadius: BorderRadius.circular(PasyarRadius.input),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            spacing: 6,
            children: [
              Icon(icon, size: 18, color: color),
              Text(
                label,
                style: PasyarTextStyles.of(
                  context,
                ).buttonSecondary.copyWith(fontSize: 16, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
