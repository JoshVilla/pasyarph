import 'package:flutter/material.dart';

import '../theme/pasyar_theme.dart';

const _disabledOpacity = 0.4;

/// Orange, 56 px, UPPERCASE condensed label. Pass `onPressed: null` to
/// disable; `loading` keeps the color but swaps the label for a spinner.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _ButtonFrame(
      label: label,
      enabled: onPressed != null,
      loading: loading,
      onPressed: onPressed,
      fill: PasyarColors.accent,
      foreground: PasyarColors.card,
      textStyle: PasyarTextStyles.buttonPrimary,
      icon: icon,
      iconSize: 22,
      iconGap: 10,
    );
  }
}

/// Outlined, 56 px. [SecondaryButton.onDark] is the white-outline variant used
/// on the dark Welcome screen.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  }) : _onDark = false;

  const SecondaryButton.onDark({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  }) : _onDark = true;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool _onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = _onDark ? PasyarColors.card : PasyarColors.ink;
    return _ButtonFrame(
      label: label,
      enabled: onPressed != null,
      loading: loading,
      onPressed: onPressed,
      fill: _onDark ? Colors.transparent : PasyarColors.card,
      border: BorderSide(color: foreground, width: 2),
      foreground: foreground,
      textStyle: PasyarTextStyles.buttonSecondary,
      icon: icon,
      iconSize: 20,
      iconGap: 8,
    );
  }
}

class _ButtonFrame extends StatelessWidget {
  const _ButtonFrame({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
    required this.fill,
    required this.foreground,
    required this.textStyle,
    required this.icon,
    required this.iconSize,
    required this.iconGap,
    this.border = BorderSide.none,
  });

  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback? onPressed;
  final Color fill;
  final Color foreground;
  final BorderSide border;
  final TextStyle textStyle;
  final IconData? icon;
  final double iconSize;
  final double iconGap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PasyarRadius.button),
      side: border,
    );
    final content = loading
        ? SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: foreground,
            ),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: iconSize, color: foreground),
                  SizedBox(width: iconGap),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: textStyle.copyWith(color: foreground),
                ),
              ],
            ),
          );

    return Semantics(
      button: true,
      enabled: enabled && !loading,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: SizedBox(
          height: 56,
          child: Material(
            color: fill,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled && !loading ? onPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button. [RoundIconButton.floating] is the 48 px white control
/// with a shadow used over the map; [RoundIconButton.ground] is the 44 px
/// `ground` button used on white screens (back, search, notifications).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton.floating({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.iconSize = 22,
  }) : _floating = true;

  const RoundIconButton.ground({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.iconSize = 22,
  }) : _floating = false;

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double iconSize;
  final bool _floating;

  @override
  Widget build(BuildContext context) {
    final size = _floating ? 48.0 : 44.0;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: _floating ? PasyarShadows.floating : null,
        ),
        child: Material(
          color: _floating ? PasyarColors.card : PasyarColors.ground,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, size: iconSize, color: PasyarColors.ink),
          ),
        ),
      ),
    );
  }
}
