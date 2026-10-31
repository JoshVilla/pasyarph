// lib/core/theme/pasyar_colors.dart
import 'package:flutter/material.dart';

class PasyarColors {
  static PasyarPalette of(BuildContext context) =>
      PasyarPalette(Theme.of(context).brightness == Brightness.dark);

  static const ink = Color(0xFF15171C);
  static const muted = Color(0xFF5A5F69);
  static const ground = Color(0xFFF3F2EE);
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFE2E0DA);
  static const lineStrong = Color(0xFFD3D5CC);
  static const accent = Color(0xFF1D4ED8);
  static const accentDark = Color(0xFF1E3A8A);
  static const accentTint = Color(0xFFEAF0FE);
  // Dark, so the rider dot and start point stand out on the blue route.
  static const rider = Color(0xFF0F172A);
  static const verifiedTint = Color(0xFFE6EEFB);
  static const verifiedText = Color(0xFF1E3A8A);
  static const mapGround = Color(0xFFF7F7F7);
  static const riddenRoute = Color(0xFF9CA0A8);

  // Dark surfaces (Welcome, riding banner), from the approved mockups.
  static const onInkMuted = Color(0xFFC9CCD2);
  static const taglineOnInk = Color(0xFF93B4FB);
  static const inkRoad = Color(0xFF262930);
  static const inkRoadMajor = Color(0xFF30343C);

  // Profile cover: the default banner (accentDark ground, roads, and a
  // taglineOnInk loop) and the "Edit cover" chip over a photo.
  static const coverRoad = Color(0xFF2B4BA6);
  static const coverChip = Color(0x8C0F172A); // rider at 55%
}

/// Semantic colors for light and Midnight Blue appearances.
class PasyarPalette {
  const PasyarPalette(this.isDark);
  final bool isDark;
  Color get background => isDark ? const Color(0xFF0B1120) : PasyarColors.card;
  Color get ink => isDark ? const Color(0xFFF1F5F9) : PasyarColors.ink;
  Color get muted => isDark ? const Color(0xFF94A3B8) : PasyarColors.muted;
  Color get ground => isDark ? const Color(0xFF10182A) : PasyarColors.ground;
  Color get card => isDark ? const Color(0xFF151E30) : PasyarColors.card;
  Color get line => isDark ? const Color(0xFF2A364B) : PasyarColors.line;
  Color get lineStrong =>
      isDark ? const Color(0xFF3C4C65) : PasyarColors.lineStrong;
  Color get accent => isDark ? const Color(0xFF739BFF) : PasyarColors.accent;
  Color get onAccent => isDark ? const Color(0xFF0B1120) : PasyarColors.card;
  Color get accentDark =>
      isDark ? const Color(0xFFA9C1FF) : PasyarColors.accentDark;
  Color get accentTint =>
      isDark ? const Color(0xFF1D3155) : PasyarColors.accentTint;
  Color get rider => PasyarColors.rider;
  Color get verifiedTint => isDark ? accentTint : PasyarColors.verifiedTint;
  Color get verifiedText => isDark ? accentDark : PasyarColors.verifiedText;
  Color get mapGround =>
      isDark ? const Color(0xFF10182A) : PasyarColors.mapGround;
  Color get riddenRoute =>
      isDark ? const Color(0xFF8290A6) : PasyarColors.riddenRoute;
  Color get onInkMuted => PasyarColors.onInkMuted;
  Color get taglineOnInk => PasyarColors.taglineOnInk;
  Color get inkRoad => PasyarColors.inkRoad;
  Color get inkRoadMajor => PasyarColors.inkRoadMajor;
  Color get coverRoad => PasyarColors.coverRoad;
  Color get coverChip => PasyarColors.coverChip;
}
