import 'package:flutter/material.dart';

import '../../../core/theme/pasyar_theme.dart';

/// A post's photos edge to edge (mockup 5): one big photo; two side by
/// side; three as one big left and two stacked right; more than three like
/// three, with "+N" over the last tile. Tapping opens the gallery at that
/// photo.
class PhotoCollage extends StatelessWidget {
  const PhotoCollage({super.key, required this.photos, required this.onTap});

  final List<ImageProvider> photos;
  final ValueChanged<int> onTap;

  static const _gap = 3.0;
  static const _row = 130.0;
  static const _single = 300.0;

  @override
  Widget build(BuildContext context) {
    final n = photos.length;
    if (n == 0) return const SizedBox.shrink();
    if (n == 1) {
      return SizedBox(height: _single, child: _tile(0));
    }
    if (n == 2) {
      return SizedBox(
        height: _row * 2 + _gap,
        child: Row(
          spacing: _gap,
          children: [
            Expanded(child: _tile(0)),
            Expanded(child: _tile(1)),
          ],
        ),
      );
    }
    return SizedBox(
      height: _row * 2 + _gap,
      child: Row(
        spacing: _gap,
        children: [
          Expanded(flex: 2, child: _tile(0)),
          Expanded(
            child: Column(
              spacing: _gap,
              children: [
                Expanded(child: _tile(1)),
                Expanded(child: _tile(2, more: n - 3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(int i, {int more = 0}) {
    return Semantics(
      button: true,
      label: more > 0 ? 'Photo ${i + 1}, $more more' : 'Photo ${i + 1}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onTap(i),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: PasyarColors.ground,
              child: Image(
                image: photos[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
            ),
            if (more > 0) ...[
              ColoredBox(color: PasyarColors.ink.withValues(alpha: 0.45)),
              Center(
                child: Text(
                  '+$more',
                  style: PasyarTextStyles.screenTitle(
                    28,
                  ).copyWith(color: PasyarColors.card),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
