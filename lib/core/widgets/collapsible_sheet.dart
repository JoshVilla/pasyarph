import 'package:flutter/material.dart';

/// How tall a collapsed map sheet stays: the drag handle and its first row
/// (the stats on the loop preview).
const sheetPeekHeight = 112.0;

/// Lets a bottom sheet over a map be dragged down to a peek (to see the
/// map) and back up; a tap on its top edge toggles it. [builder] lays out
/// the map and sheet for a collapse fraction (0 = open, 1 = collapsed) and
/// wraps the sheet with `wrapSheet`, which adds the gestures. Give it a
/// `GlobalKey<CollapsibleSheetState>` to open or close it from a button.
class CollapsibleSheet extends StatefulWidget {
  const CollapsibleSheet({
    super.key,
    required this.builder,
    this.enabled = true,
    this.peek = sheetPeekHeight,
    this.startCollapsed = false,
  });

  final Widget Function(
    BuildContext context,
    double collapsed,
    Widget Function(Widget sheet) wrapSheet,
  )
  builder;

  /// False keeps the sheet open (e.g. while typing in it).
  final bool enabled;

  final double peek;

  /// Opens lowered to the peek (the map first).
  final bool startCollapsed;

  @override
  State<CollapsibleSheet> createState() => CollapsibleSheetState();
}

class CollapsibleSheetState extends State<CollapsibleSheet>
    with SingleTickerProviderStateMixin {
  late final _collapse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: widget.startCollapsed ? 1 : 0,
  )..addListener(() => setState(() {}));

  bool get isCollapsed => _collapse.value > 0.5;

  /// Raises the sheet all the way.
  void open() => _collapse.animateTo(0, curve: Curves.easeOut);

  /// Lowers the sheet to its peek.
  void close() {
    if (widget.enabled) _collapse.animateTo(1, curve: Curves.easeOut);
  }
  final _sheetKey = GlobalKey();

  @override
  void didUpdateWidget(CollapsibleSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _collapse.value > 0) _collapse.animateTo(0);
  }

  @override
  void dispose() {
    _collapse.dispose();
    super.dispose();
  }

  /// How far the sheet can travel down.
  double get _range {
    final box = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    final height = box?.hasSize == true ? box!.size.height : 0.0;
    return (height - widget.peek).clamp(1.0, double.infinity);
  }

  void _drag(DragUpdateDetails d) {
    if (!widget.enabled) return;
    _collapse.value = (_collapse.value + d.primaryDelta! / _range).clamp(
      0.0,
      1.0,
    );
  }

  void _settle(DragEndDetails d) {
    if (!widget.enabled) return;
    final v = d.primaryVelocity ?? 0;
    final down = v.abs() > 300 ? v > 0 : _collapse.value > 0.5;
    _collapse.animateTo(down ? 1 : 0, curve: Curves.easeOut);
  }

  void _toggle() =>
      _collapse.animateTo(_collapse.value > 0.5 ? 0 : 1, curve: Curves.easeOut);

  Widget _wrap(Widget sheet) {
    final collapsed = _collapse.value > 0.5;
    return GestureDetector(
      key: _sheetKey,
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: widget.enabled ? _drag : null,
      onVerticalDragEnd: widget.enabled ? _settle : null,
      child: Stack(
        children: [
          sheet,
          // The handle row (44 px, for gloves): a tap toggles.
          if (widget.enabled)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 44,
              child: Semantics(
                // Its own node, sized to the handle row.
                container: true,
                button: true,
                label: collapsed
                    ? 'Show details'
                    : 'Hide details to see the map',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _collapse.value, _wrap);
}
