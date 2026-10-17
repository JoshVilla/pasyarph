import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';

/// 88 px profile photo button from mockup 10: dashed `lineStrong` circle on
/// `ground` with a person icon, and an orange camera badge. Shows the photo
/// once one is picked.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.onTap,
    this.preview,
    this.url,
    this.uploading = false,
  });

  final VoidCallback? onTap;
  final Uint8List? preview;
  final String? url;
  final bool uploading;

  static const size = 88.0;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = preview != null
        ? MemoryImage(preview!)
        : (url != null ? NetworkImage(url!) : null);

    return Semantics(
      button: true,
      label: image == null ? 'Add profile photo' : 'Change profile photo',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: image == null
                    ? CustomPaint(
                        painter: _DashedCirclePainter(),
                        child: const Center(
                          child: Icon(
                            LucideIcons.user,
                            size: 34,
                            color: PasyarColors.muted,
                          ),
                        ),
                      )
                    : ClipOval(
                        child: Image(
                          image: image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: PasyarColors.ground),
                        ),
                      ),
              ),
              if (uploading)
                const Positioned.fill(
                  child: ClipOval(
                    child: ColoredBox(
                      color: Color(0x6615171C),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: PasyarColors.card,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: PasyarColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: PasyarColors.card, width: 3),
                  ),
                  child: const Icon(
                    LucideIcons.camera,
                    size: 16,
                    color: PasyarColors.card,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 2.0;
    final radius = size.width / 2 - stroke / 2;
    canvas.drawCircle(center, radius, Paint()..color = PasyarColors.ground);

    // CSS-like dashes: about 6 on, 4 off around the circle.
    final dashes = (2 * math.pi * radius / 10).floor();
    final step = 2 * math.pi / dashes;
    final paint = Paint()
      ..color = PasyarColors.lineStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * step, step * 0.6, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) => false;
}
