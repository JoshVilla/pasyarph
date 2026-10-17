import 'package:flutter/material.dart';

import 'pasyar_colors.dart';

/// Font families bundled in pubspec.yaml (Google Fonts, OFL).
abstract final class PasyarFonts {
  static const display = 'Barlow Condensed';
  static const body = 'Barlow';
}

/// One style per row of the Typography table in design/DESIGN.md.
/// Strings for UPPERCASE styles are written in uppercase by the caller.
abstract final class PasyarTextStyles {
  static const _display = TextStyle(
    fontFamily: PasyarFonts.display,
    fontWeight: FontWeight.w700,
    color: PasyarColors.ink,
  );
  static const _body = TextStyle(
    fontFamily: PasyarFonts.body,
    fontWeight: FontWeight.w400,
    color: PasyarColors.ink,
  );

  /// "PASYAR" on Welcome only.
  static final wordmark = _display.copyWith(
    fontSize: 72,
    letterSpacing: 1,
    height: 0.95,
  );

  /// Welcome tagline, shown on ink.
  static final tagline = _display.copyWith(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFF2A27A),
  );

  /// UPPERCASE screen titles. Home 30, Feed 32, Onboarding 34,
  /// Post / Log in / Register 36.
  static TextStyle screenTitle([double size = 36]) =>
      _display.copyWith(fontSize: size, letterSpacing: 0.5);

  /// Riding banner distance.
  static final navDistance = _display.copyWith(fontSize: 40, height: 1.0);

  /// Distance, ride time. Use [statValueSmall] inside feed cards.
  static final statValue = _display.copyWith(fontSize: 28);
  static final statValueSmall = _display.copyWith(fontSize: 22);

  static final buttonPrimary = _display.copyWith(
    fontSize: 22,
    letterSpacing: 1,
  );
  static final buttonSecondary = _display.copyWith(
    fontSize: 20,
    letterSpacing: 1,
  );

  /// QUICK / HALF-DAY / FULL DAY.
  static final choiceTitle = _display.copyWith(fontSize: 20);

  /// Floating "HALF-DAY LOOP" pill.
  static final pillTitle = _display.copyWith(fontSize: 18, letterSpacing: 0.5);

  /// Stop names.
  static final bodyLarge = _body.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  /// Default text and feed captions.
  static final body = _body.copyWith(fontSize: 15, height: 1.4);
  static final bodyStrong = body.copyWith(fontWeight: FontWeight.w600);

  /// Toggles, secondary lines.
  static final bodySmall = _body.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  /// Stat labels and meta lines ("2 h ago · …").
  static final label = _body.copyWith(fontSize: 13, color: PasyarColors.muted);

  /// Labels above inputs and option groups ("Email", "What do you ride?").
  static final fieldLabel = _body.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: PasyarColors.muted,
  );

  /// UPPERCASE overlines like "MAIN STOP · 52 KM IN".
  static final overline = _body.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: PasyarColors.accentDark,
  );

  static final tabLabel = _body.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
  static final tabLabelActive = tabLabel.copyWith(fontWeight: FontWeight.w600);
}
