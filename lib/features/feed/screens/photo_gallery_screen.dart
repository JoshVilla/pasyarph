import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';

/// A post's photos full screen on black: swipe between them, pinch to zoom.
/// Opened from a feed card at the tapped photo.
class PhotoGalleryScreen extends StatefulWidget {
  const PhotoGalleryScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  final List<ImageProvider> photos;
  final int initialIndex;

  static Future<void> open(
    BuildContext context,
    List<ImageProvider> photos, {
    int at = 0,
  }) => Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => PhotoGalleryScreen(photos: photos, initialIndex: at),
    ),
  );

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + PasyarSpacing.floatingTop;
    return Scaffold(
      backgroundColor: PasyarColors.ink,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: Image(
                  image: widget.photos[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    LucideIcons.imageOff,
                    color: PasyarColors.onInkMuted,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: top,
            left: PasyarSpacing.screen,
            right: PasyarSpacing.screen,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CloseButton(onPressed: () => Navigator.pop(context)),
                if (widget.photos.length > 1)
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: PasyarColors.ink.withValues(alpha: 0.75),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.photos.length}',
                      style: PasyarTextStyles.label.copyWith(
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: PasyarColors.card,
                      ),
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

/// 44 px close button, white icon on translucent ink.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PasyarColors.ink.withValues(alpha: 0.75),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const SizedBox.square(
          dimension: PasyarSpacing.minTouch,
          child: Icon(LucideIcons.x, size: 22, color: PasyarColors.card),
        ),
      ),
    );
  }
}
