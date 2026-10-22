import 'package:flutter/material.dart';

import '../theme/pasyar_theme.dart';

/// Round profile picture with an initials fallback. Feed sizes: 44 (post
/// author), 40 (composer), 32 (comment).
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.image,
    this.size = 44,
    this.color,
  });

  final String name;
  final ImageProvider? image;
  final double size;

  /// Background behind the initials. Defaults to a color picked from [name].
  final Color? color;

  static const _palette = [
    PasyarColors.verifiedText,
    PasyarColors.ink,
    PasyarColors.accentDark,
    PasyarColors.muted,
  ];

  static String initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w.characters.first).join();
    return letters.isEmpty ? '?' : letters.toUpperCase();
  }

  static Color colorFor(String name) {
    final hash = name.codeUnits.fold<int>(
      0,
      (h, c) => (h * 31 + c) & 0x7fffffff,
    );
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final initials = Text(
      initialsOf(name),
      style: PasyarTextStyles.body.copyWith(
        height: 1,
        // Feed sizes use 12 / 15; profile and club headers (64+) scale.
        fontSize: size <= 32 ? 12 : (size < 64 ? 15 : size * 0.36),
        fontWeight: FontWeight.w600,
        color: PasyarColors.card,
      ),
    );

    return Semantics(
      image: true,
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? colorFor(name),
        ),
        child: image == null
            ? initials
            : Image(
                image: image!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => initials,
              ),
      ),
    );
  }
}
