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
  static PasyarTypography of(BuildContext context) =>
      PasyarTypography(PasyarColors.of(context));

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
    color: PasyarColors.taglineOnInk,
  );

  /// UPPERCASE screen titles. Home 30, Feed 32, Onboarding 34,
  /// Post / Log in / Register 36.
  static TextStyle screenTitle([double size = 36]) =>
      _display.copyWith(fontSize: size, letterSpacing: 0.5, height: 1.2);

  /// Riding banner distance.
  static final navDistance = _display.copyWith(fontSize: 40, height: 1.0);

  /// Distance, ride time. Use [statValueSmall] inside feed cards.
  static final statValue = _display.copyWith(fontSize: 28);
  static final statValueSmall = _display.copyWith(fontSize: 22);

  static final buttonPrimary = _body.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
  static final buttonSecondary = _body.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );

  /// QUICK / HALF-DAY / FULL DAY.
  static final choiceTitle = _body.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

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
  static final label = _body.copyWith(
    fontSize: 14,
    height: 1.35,
    color: PasyarColors.muted,
  );

  /// Labels above inputs and option groups ("Email", "What do you ride?").
  static final fieldLabel = _body.copyWith(
    fontSize: 14,
    height: 1.3,
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

/// The bundled typography with colors from the active theme.
class PasyarTypography {
  const PasyarTypography(this.colors);
  final PasyarPalette colors;
  TextStyle screenTitle([double size = 36]) =>
      PasyarTextStyles.screenTitle(size).copyWith(color: colors.ink);
  TextStyle get wordmark =>
      PasyarTextStyles.wordmark.copyWith(color: colors.ink);
  TextStyle get tagline =>
      PasyarTextStyles.tagline.copyWith(color: colors.taglineOnInk);
  TextStyle get navDistance =>
      PasyarTextStyles.navDistance.copyWith(color: colors.ink);
  TextStyle get statValue =>
      PasyarTextStyles.statValue.copyWith(color: colors.ink);
  TextStyle get statValueSmall =>
      PasyarTextStyles.statValueSmall.copyWith(color: colors.ink);
  TextStyle get buttonPrimary =>
      PasyarTextStyles.buttonPrimary.copyWith(color: colors.ink);
  TextStyle get buttonSecondary =>
      PasyarTextStyles.buttonSecondary.copyWith(color: colors.ink);
  TextStyle get choiceTitle =>
      PasyarTextStyles.choiceTitle.copyWith(color: colors.ink);
  TextStyle get pillTitle =>
      PasyarTextStyles.pillTitle.copyWith(color: colors.ink);
  TextStyle get bodyLarge =>
      PasyarTextStyles.bodyLarge.copyWith(color: colors.ink);
  TextStyle get body => PasyarTextStyles.body.copyWith(color: colors.ink);
  TextStyle get bodyStrong =>
      PasyarTextStyles.bodyStrong.copyWith(color: colors.ink);
  TextStyle get bodySmall =>
      PasyarTextStyles.bodySmall.copyWith(color: colors.ink);
  TextStyle get label => PasyarTextStyles.label.copyWith(color: colors.muted);
  TextStyle get fieldLabel =>
      PasyarTextStyles.fieldLabel.copyWith(color: colors.muted);
  TextStyle get overline =>
      PasyarTextStyles.overline.copyWith(color: colors.accentDark);
  TextStyle get tabLabel =>
      PasyarTextStyles.tabLabel.copyWith(color: colors.ink);
  TextStyle get tabLabelActive =>
      PasyarTextStyles.tabLabelActive.copyWith(color: colors.ink);
}
