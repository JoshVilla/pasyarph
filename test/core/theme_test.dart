import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/core/settings/app_settings.dart';
import 'package:pasyarph/core/theme/pasyar_theme.dart';
import '../support/fake_me.dart';

void main() {
  test(
    'appearance defaults to System and survives a settings reload',
    () async {
      final store = MemorySettingsStore();
      final settings = AppSettings(store);
      await settings.load();
      expect(settings.themeMode, ThemeMode.system);
      for (final mode in [ThemeMode.dark, ThemeMode.light, ThemeMode.system]) {
        await settings.setThemeMode(mode);
        final restored = AppSettings(store);
        await restored.load();
        expect(restored.themeMode, mode);
        restored.dispose();
      }
      store.strings['settings.theme_mode'] = 'unknown';
      await settings.load();
      expect(settings.themeMode, ThemeMode.system);
      settings.dispose();
    },
  );

  test('Midnight Blue uses the selected palette with readable contrast', () {
    const colors = PasyarPalette(true);
    final theme = PasyarTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(colors.background, const Color(0xFF0B1120));
    expect(colors.card, const Color(0xFF151E30));
    expect(colors.ink, const Color(0xFFF1F5F9));
    expect(colors.muted, const Color(0xFF94A3B8));
    expect(colors.accent, const Color(0xFF739BFF));
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
    }

    expect(contrast(colors.ink, colors.card), greaterThanOrEqualTo(4.5));
    expect(contrast(colors.muted, colors.card), greaterThanOrEqualTo(4.5));
    expect(contrast(colors.onAccent, colors.accent), greaterThanOrEqualTo(4.5));
  });
}
