import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/pasyar_theme.dart';
import 'map_markers.dart';
import '../widgets/motion.dart';

/// One symbol a map draws, as its key explains it.
enum MapKeyItem {
  /// The S marker where a loop starts (and ends).
  startS('Start (you)'),
  points('Your points'),
  mainStop('Main stop'),
  fuel('Fuel'),
  overnights('Overnight towns'),
  direction('Riding direction'),
  backToStart('Back to start');

  const MapKeyItem(this.label);
  final String label;

  String get _spoken => switch (this) {
    startS => 'S is your start.',
    points => 'Numbers are your points.',
    mainStop => 'The flag is the main stop.',
    fuel => 'The pump is a fuel station.',
    overnights => 'Numbers are the overnight towns.',
    direction => 'Arrows show the riding direction.',
    backToStart => 'The dashed line leads back to the start.',
  };
}

/// A map's key: what each symbol on it means, drawn with the map's own
/// markers. As a column (Create) or a wrapping row (loop preview). A tap
/// folds it into a small "Map key" chip ([open] false); another opens it.
class MapLegend extends StatelessWidget {
  const MapLegend({
    super.key,
    required this.items,
    required this.open,
    required this.onToggle,
    this.row = false,
  });

  final List<MapKeyItem> items;
  final bool open;
  final VoidCallback onToggle;

  /// Lay the items out in wrapping rows instead of one column.
  final bool row;

  @override
  Widget build(BuildContext context) =>
      MotionSize(alignment: Alignment.bottomLeft, child: _content(context));

  Widget _content(BuildContext context) {
    final card = BoxDecoration(
      color: PasyarColors.of(context).card,
      borderRadius: BorderRadius.circular(PasyarRadius.panel),
      boxShadow: PasyarShadows.floating,
    );
    if (!open) {
      return Semantics(
        button: true,
        label: 'Show map key',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onToggle,
          child: Container(
            height: PasyarSpacing.minTouch,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: card,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(
                  LucideIcons.info,
                  size: 18,
                  color: PasyarColors.of(context).accentDark,
                ),
                Text(
                  'Map key',
                  style: PasyarTextStyles.of(context).label.copyWith(
                    fontWeight: FontWeight.w600,
                    color: PasyarColors.of(context).ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final entries = [for (final i in items) _Item(item: i)];
    return GestureDetector(
      onTap: onToggle,
      child: Semantics(
        container: true,
        button: true,
        label: ['Map key.', for (final i in items) i._spoken].join(' '),
        hint: 'Tap to hide',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: card,
          child: row
              ? Wrap(spacing: 14, runSpacing: 6, children: entries)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: entries,
                ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item});

  final MapKeyItem item;

  Widget get _symbol => switch (item) {
    MapKeyItem.startS => const _Scaled(child: LoopPointMarker.start()),
    MapKeyItem.points ||
    MapKeyItem.overnights => const _Scaled(child: LoopPointMarker(label: '1')),
    MapKeyItem.mainStop => const _Scaled(child: MainStopMarker(radius: 12)),
    MapKeyItem.fuel => const _Scaled(child: FuelMarker()),
    MapKeyItem.direction => const CustomPaint(
      size: Size(24, 12),
      painter: _DirectionPainter(),
    ),
    MapKeyItem.backToStart => const CustomPaint(
      size: Size(22, 4),
      painter: _DashPainter(),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        SizedBox.square(dimension: 24, child: Center(child: _symbol)),
        Text(
          item.label,
          style: PasyarTextStyles.of(context).label.copyWith(
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: PasyarColors.of(context).ink,
          ),
        ),
      ],
    );
  }
}

/// A map marker shrunk to the key's 24 px row.
class _Scaled extends StatelessWidget {
  const _Scaled({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      FittedBox(fit: BoxFit.contain, child: child);
}

/// A short piece of route as the map draws it: white casing, the accent
/// line, and a white chevron inside (RouteArrowsLayer).
class _DirectionPainter extends CustomPainter {
  const _DirectionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final a = Offset(1, y);
    final b = Offset(size.width - 1, y);
    canvas
      ..drawLine(
        a,
        b,
        Paint()
          ..color = PasyarColors.card
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round,
      )
      ..drawLine(
        a,
        b,
        Paint()
          ..color = PasyarColors.accent
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    final c = size.width / 2;
    canvas.drawPath(
      Path()
        ..moveTo(c - 2, y - 3.5)
        ..lineTo(c + 2, y)
        ..lineTo(c - 2, y + 3.5),
      Paint()
        ..color = PasyarColors.card
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_DirectionPainter oldDelegate) => false;
}

/// A short piece of the dashed closing line, on its white casing.
class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = PasyarColors.card
        ..strokeWidth = 7,
    );
    final paint = Paint()
      ..color = PasyarColors.accent
      ..strokeWidth = 4;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x + 6, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}
