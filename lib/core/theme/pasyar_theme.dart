import 'package:flutter/material.dart';

import 'pasyar_colors.dart';
import 'pasyar_text_styles.dart';

export 'pasyar_colors.dart';
export 'pasyar_spacing.dart';
export 'pasyar_text_styles.dart';

abstract final class PasyarTheme {
  static ThemeData light() => _build(false);
  static ThemeData dark() => _build(true);

  static ThemeData _build(bool dark) {
    final colors = PasyarPalette(dark);
    final scheme = ColorScheme(
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      primaryContainer: colors.accentTint,
      onPrimaryContainer: colors.accentDark,
      secondary: colors.ink,
      onSecondary: colors.card,
      tertiary: colors.rider,
      onTertiary: colors.card,
      error: colors.accent,
      onError: colors.onAccent,
      surface: colors.card,
      onSurface: colors.ink,
      onSurfaceVariant: colors.muted,
      surfaceContainerHighest: colors.ground,
      outline: colors.line,
      outlineVariant: colors.lineStrong,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: PasyarFonts.body,
      scaffoldBackgroundColor: colors.background,
      dividerColor: colors.line,
      textTheme:
          TextTheme(
            displayLarge: PasyarTextStyles.wordmark,
            headlineLarge: PasyarTextStyles.screenTitle(),
            titleLarge: PasyarTextStyles.choiceTitle,
            titleMedium: PasyarTextStyles.bodyLarge,
            bodyLarge: PasyarTextStyles.body,
            bodyMedium: PasyarTextStyles.body,
            bodySmall: PasyarTextStyles.label,
            labelLarge: PasyarTextStyles.bodySmall,
            labelSmall: PasyarTextStyles.overline,
          ).apply(
            bodyColor: dark ? colors.ink : null,
            displayColor: dark ? colors.ink : null,
          ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.accentTint,
        selectionHandleColor: colors.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
    );
  }
}
