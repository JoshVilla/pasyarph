import 'package:flutter/material.dart';

import '../theme/pasyar_theme.dart';

/// Square checkbox tinted `accent`, matching the native checkbox in the
/// mockups. Visual only; wrap it in something tappable.
class PasyarCheckbox extends StatelessWidget {
  const PasyarCheckbox({super.key, required this.value, this.size = 18});

  final bool value;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: value ? PasyarColors.accent : PasyarColors.card,
        borderRadius: BorderRadius.circular(3),
        border: value
            ? null
            : Border.all(color: PasyarColors.muted, width: 1.5),
      ),
      child: value
          ? CustomPaint(painter: _CheckPainter(), size: Size.square(size))
          : null,
    );
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.22, s * 0.52)
      ..lineTo(s * 0.42, s * 0.72)
      ..lineTo(s * 0.78, s * 0.3);
    canvas.drawPath(
      path,
      Paint()
        ..color = PasyarColors.card
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.14
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => false;
}

/// 44 px `ground` pill with a checkbox, e.g. "Avoid highways".
class PillToggle extends StatelessWidget {
  const PillToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      enabled: onChanged != null,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        height: 44,
        child: Material(
          color: PasyarColors.ground,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onChanged == null ? null : () => onChanged!(!value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                spacing: 8,
                children: [
                  PasyarCheckbox(value: value),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PasyarTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feed filter chip ("Near you", "Following", ...). The pill is 36 px tall
/// but the tap area is 44 px.
class PasyarFilterChip extends StatelessWidget {
  const PasyarFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: selected ? PasyarColors.ink : PasyarColors.card,
                shape: StadiumBorder(
                  side: selected
                      ? BorderSide.none
                      : const BorderSide(
                          color: PasyarColors.lineStrong,
                          width: 1.5,
                        ),
                ),
              ),
              child: Text(
                label,
                style: PasyarTextStyles.bodySmall.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? PasyarColors.card : PasyarColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
