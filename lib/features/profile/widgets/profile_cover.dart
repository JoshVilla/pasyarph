import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';

/// The banner's height below the status bar.
const coverHeight = 150.0;

/// Full-width profile banner: the rider's cover photo (with a soft dark
/// gradient at the top so white icons stay readable), or the default blue
/// banner with a faint loop. [leading] and [actions] sit at the top, below
/// the status bar; [onEditCover] adds the "Edit cover" chip (own profile).
class ProfileCover extends StatelessWidget {
  const ProfileCover({
    super.key,
    this.image,
    this.leading,
    this.actions = const [],
    this.onEditCover,
    this.busy = false,
  });

  final ImageProvider? image;
  final Widget? leading;
  final List<Widget> actions;
  final VoidCallback? onEditCover;

  /// Uploading or removing: a progress bar over the banner.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final image = this.image;
    return SizedBox(
      height: top + coverHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: DefaultCoverPainter()),
          if (image != null) ...[
            Image(
              image: image,
              fit: BoxFit.cover,
              // A broken link falls back to the default banner.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Color(0x6615171C), Color(0x0015171C)],
                ),
              ),
            ),
          ],
          if (busy)
            const Align(
              alignment: Alignment.bottomCenter,
              child: LinearProgressIndicator(
                minHeight: 3,
                color: PasyarColors.card,
                backgroundColor: Color(0x33FFFFFF),
              ),
            ),
          Positioned(
            top: top + 8,
            left: PasyarSpacing.screen,
            right: PasyarSpacing.screen,
            child: Row(children: [?leading, const Spacer(), ...actions]),
          ),
          if (onEditCover != null)
            Positioned(
              right: PasyarSpacing.screen,
              bottom: 12,
              child: _EditCoverChip(onTap: busy ? null : onEditCover),
            ),
        ],
      ),
    );
  }
}

/// White 44 px icon button for the banner (share, settings, back, more).
class CoverIconButton extends StatelessWidget {
  const CoverIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: PasyarColors.card,
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: PasyarSpacing.minTouch,
              child: Icon(icon, size: 20, color: PasyarColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditCoverChip extends StatelessWidget {
  const _EditCoverChip({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Edit cover',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // 32 px chip, 44 px tap area.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const ShapeDecoration(
              color: PasyarColors.coverChip,
              shape: StadiumBorder(),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                const Icon(
                  LucideIcons.camera,
                  size: 16,
                  color: PasyarColors.card,
                ),
                Text(
                  'Edit cover',
                  style: PasyarTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    color: PasyarColors.card,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The default banner: deep blue, a few faint roads, and a loop drawn over
/// them.
class DefaultCoverPainter extends CustomPainter {
  const DefaultCoverPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = PasyarColors.accentDark,
    );

    final road = Paint()
      ..color = PasyarColors.coverRoad
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(0, h * 0.62), Offset(w, h * 0.48), road)
      ..drawLine(Offset(w * 0.18, 0), Offset(w * 0.30, h), road)
      ..drawLine(Offset(w * 0.64, 0), Offset(w * 0.58, h), road)
      ..drawLine(Offset(w * 0.80, h), Offset(w, h * 0.70), road);

    final loop = Path()
      ..moveTo(w * 0.40, h * 0.86)
      ..cubicTo(w * 0.22, h * 0.86, w * 0.20, h * 0.40, w * 0.36, h * 0.34)
      ..cubicTo(w * 0.50, h * 0.28, w * 0.60, h * 0.20, w * 0.74, h * 0.30)
      ..cubicTo(w * 0.88, h * 0.40, w * 0.84, h * 0.70, w * 0.66, h * 0.78)
      ..cubicTo(w * 0.56, h * 0.82, w * 0.50, h * 0.86, w * 0.40, h * 0.86)
      ..close();
    canvas.drawPath(
      loop,
      Paint()
        ..color = PasyarColors.taglineOnInk.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(DefaultCoverPainter oldDelegate) => false;
}
