import 'package:flutter/material.dart';

import 'pasyar_colors.dart';
import 'pasyar_text_styles.dart';

export 'pasyar_colors.dart';
export 'pasyar_spacing.dart';
export 'pasyar_text_styles.dart';

abstract final class PasyarTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: PasyarColors.accent,
      onPrimary: PasyarColors.card,
      primaryContainer: PasyarColors.accentTint,
      onPrimaryContainer: PasyarColors.accentDark,
      secondary: PasyarColors.ink,
      onSecondary: PasyarColors.card,
      tertiary: PasyarColors.rider,
      onTertiary: PasyarColors.card,
      error: PasyarColors.accent,
      onError: PasyarColors.card,
      surface: PasyarColors.card,
      onSurface: PasyarColors.ink,
      onSurfaceVariant: PasyarColors.muted,
      surfaceContainerHighest: PasyarColors.ground,
      outline: PasyarColors.line,
      outlineVariant: PasyarColors.lineStrong,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: PasyarFonts.body,
      scaffoldBackgroundColor: PasyarColors.card,
      dividerColor: PasyarColors.line,
      textTheme: TextTheme(
        displayLarge: PasyarTextStyles.wordmark,
        headlineLarge: PasyarTextStyles.screenTitle(),
        titleLarge: PasyarTextStyles.choiceTitle,
        titleMedium: PasyarTextStyles.bodyLarge,
        bodyLarge: PasyarTextStyles.body,
        bodyMedium: PasyarTextStyles.body,
        bodySmall: PasyarTextStyles.label,
        labelLarge: PasyarTextStyles.bodySmall,
        labelSmall: PasyarTextStyles.overline,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: PasyarColors.accent,
        selectionColor: PasyarColors.accentTint,
        selectionHandleColor: PasyarColors.accent,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PasyarColors.accent,
      ),
    );
  }
}
