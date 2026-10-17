import 'package:flutter/widgets.dart';

/// Spacing from "Spacing, radius, elevation" in design/DESIGN.md.
abstract final class PasyarSpacing {
  /// Inside bottom sheets and full-screen forms.
  static const sheet = 20.0;

  /// Floating controls and feed content.
  static const screen = 16.0;

  /// Floating controls sit this far below the real safe area.
  static const floatingTop = 12.0;

  static const groupGap = 16.0;
  static const buttonGap = 10.0;
  static const chipGap = 8.0;

  /// Minimum touch target (riders may wear gloves).
  static const minTouch = 44.0;
}

abstract final class PasyarRadius {
  static const sheet = 24.0;
  static const button = 16.0;
  static const choiceCard = 14.0;
  static const social = 14.0;
  static const feedCard = 20.0;
  static const panel = 16.0;
  static const input = 12.0;
  static const thumbnail = 12.0;
  static const photoSlot = 10.0;
  static const pill = 999.0;
}

abstract final class PasyarShadows {
  static const floating = [
    BoxShadow(color: Color(0x1F15171C), offset: Offset(0, 2), blurRadius: 8),
  ];
  static const sheet = [
    BoxShadow(color: Color(0x1A15171C), offset: Offset(0, -4), blurRadius: 16),
  ];
}
