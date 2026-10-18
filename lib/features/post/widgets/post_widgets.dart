import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/route_thumbnail.dart';

/// "Rode this loop": the verified badge (mockup 4, top right).
class RodeBadge extends StatelessWidget {
  const RodeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: PasyarColors.verifiedTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          const Icon(
            LucideIcons.check,
            size: 16,
            color: PasyarColors.verifiedText,
          ),
          Text(
            'Rode this loop',
            style: PasyarTextStyles.body.copyWith(
              fontSize: 13,
              height: 1,
              fontWeight: FontWeight.w600,
              color: PasyarColors.verifiedText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Five columns of square slots: photos, then the add slot, then dashed
/// empty slots up to [total].
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onPhotoTap,
    this.adding = false,
    this.total = 10,
  });

  /// Photo file paths.
  final List<String> photos;

  /// Null hides the add slot's action (posting, or full).
  final VoidCallback? onAdd;
  final ValueChanged<int> onPhotoTap;
  final bool adding;
  final int total;

  static const _columns = 5;
  static const _gap = 8.0;

  // Rows of Expanded squares rather than a LayoutBuilder, so the grid can
  // report its height before layout (the post screen needs that).
  @override
  Widget build(BuildContext context) {
    final slots = <Widget>[
      for (var i = 0; i < photos.length; i++)
        _PhotoSlot(path: photos[i], onTap: () => onPhotoTap(i)),
      if (photos.length < total) _AddSlot(onTap: onAdd, loading: adding),
    ];
    while (slots.length < total) {
      slots.add(const _EmptySlot());
    }
    return Column(
      spacing: _gap,
      children: [
        for (var row = 0; row < slots.length; row += _columns)
          Row(
            spacing: _gap,
            children: [
              for (final s in slots.skip(row).take(_columns))
                Expanded(child: AspectRatio(aspectRatio: 1, child: s)),
            ],
          ),
      ],
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Photo, tap to remove',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PasyarRadius.photoSlot),
          child: ColoredBox(
            color: PasyarColors.ground,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.onTap, required this.loading});

  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(PasyarRadius.photoSlot);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Add photos',
      excludeSemantics: true,
      child: Material(
        color: PasyarColors.accentTint,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: PasyarColors.accent, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: loading ? null : onTap,
          child: Center(
            child: loading
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: PasyarColors.accentDark,
                    ),
                  )
                : const Icon(
                    LucideIcons.camera,
                    size: 24,
                    color: PasyarColors.accentDark,
                  ),
          ),
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(painter: _DashedSlotPainter());
}

/// 1.5 px dashed `lineStrong` rounded square.
class _DashedSlotPainter extends CustomPainter {
  const _DashedSlotPainter();

  static const _dash = 4.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 1.5;
    final rect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(w / 2),
      const Radius.circular(PasyarRadius.photoSlot),
    );
    final paint = Paint()
      ..color = PasyarColors.lineStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + _dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSlotPainter oldDelegate) => false;
}

/// "Route attached": the loop's shape and its length and ride time.
class RouteAttachedCard extends StatelessWidget {
  const RouteAttachedCard({
    super.key,
    required this.route,
    required this.detail,
  });

  final List<LatLng> route;

  /// "118 km loop · 3 h 50 ride time".
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PasyarColors.ground,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
      ),
      child: Row(
        spacing: 14,
        children: [
          RouteThumbnail(route: route),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text('Route attached', style: PasyarTextStyles.bodyStrong),
                Text(
                  detail,
                  style: PasyarTextStyles.body.copyWith(
                    fontSize: 14,
                    color: PasyarColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
