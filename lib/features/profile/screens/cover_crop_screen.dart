import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../me/cover_image.dart';

/// Move and zoom a photo inside a frame shaped like the cover banner
/// (390:150). Pops the part of the photo inside the frame, in image pixels
/// of [source], or null on Cancel.
class CoverCropScreen extends StatefulWidget {
  const CoverCropScreen({super.key, required this.source});

  final CoverSource source;

  static Future<Rect?> open(BuildContext context, CoverSource source) =>
      Navigator.of(context).push<Rect>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CoverCropScreen(source: source),
        ),
      );

  @override
  State<CoverCropScreen> createState() => _CoverCropScreenState();
}

class _CoverCropScreenState extends State<CoverCropScreen> {
  final _transform = TransformationController();

  /// Starts with the middle of the photo in the frame.
  bool _centered = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _use(Size frame) {
    final m = _transform.value;
    final t = m.getTranslation();
    Navigator.of(context).pop(
      coverCropRect(
        imageWidth: widget.source.width.toDouble(),
        imageHeight: widget.source.height.toDouble(),
        frameWidth: frame.width,
        frameHeight: frame.height,
        scale: m.getMaxScaleOnAxis(),
        dx: t.x,
        dy: t.y,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final pad = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PasyarColors.ink,
        body: LayoutBuilder(
          builder: (context, c) {
            final frame = Size(
              c.maxWidth - 2 * PasyarSpacing.screen,
              (c.maxWidth - 2 * PasyarSpacing.screen) / coverAspect,
            );
            // The photo drawn to cover the frame, then zoomed and moved.
            final base = [
              frame.width / source.width,
              frame.height / source.height,
            ].reduce((a, b) => a > b ? a : b);
            if (!_centered) {
              _centered = true;
              final dx = (source.width * base - frame.width) / 2;
              final dy = (source.height * base - frame.height) / 2;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _transform.value = Matrix4.translationValues(-dx, -dy, 0);
                }
              });
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                PasyarSpacing.screen,
                pad.top + 12,
                PasyarSpacing.screen,
                pad.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'MOVE AND ZOOM',
                    style: PasyarTextStyles.of(
                      context,
                    ).screenTitle(28).copyWith(color: PasyarColors.card),
                  ),
                  Text(
                    'This is how your cover fits the top of your profile.',
                    style: PasyarTextStyles.of(
                      context,
                    ).body.copyWith(color: PasyarColors.of(context).onInkMuted),
                  ),
                  const Spacer(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox.fromSize(
                      size: frame,
                      child: InteractiveViewer(
                        transformationController: _transform,
                        constrained: false,
                        minScale: 1,
                        maxScale: 5,
                        boundaryMargin: EdgeInsets.zero,
                        child: Image.memory(
                          source.bytes,
                          width: source.width * base,
                          height: source.height * base,
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    spacing: PasyarSpacing.buttonGap,
                    children: [
                      Expanded(
                        child: SecondaryButton.onDark(
                          label: 'CANCEL',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      Expanded(
                        child: PrimaryButton(
                          label: 'USE PHOTO',
                          onPressed: () => _use(frame),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
