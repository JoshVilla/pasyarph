import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/pasyar_theme.dart';

class PasyarTab {
  const PasyarTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Ride, Feed, Create, Me — in this order.
const pasyarTabs = [
  PasyarTab(icon: LucideIcons.rotateCw, label: 'Ride'),
  PasyarTab(icon: LucideIcons.image, label: 'Feed'),
  PasyarTab(icon: LucideIcons.route, label: 'Create'),
  PasyarTab(icon: LucideIcons.user, label: 'Me'),
];

/// White tab bar, 60 px of tabs plus at least 16 px bottom padding (more on
/// phones with a larger bottom inset). Active tab is `accent`.
class PasyarBottomTabs extends StatelessWidget {
  const PasyarBottomTabs({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.tabs = pasyarTabs,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<PasyarTab> tabs;

  @override
  Widget build(BuildContext context) {
    final bottom = math.max(16.0, MediaQuery.viewPaddingOf(context).bottom);
    return Container(
      height: 60 + bottom,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: PasyarColors.card,
        border: Border(top: BorderSide(color: PasyarColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: _TabButton(
                tab: tabs[i],
                active: i == currentIndex,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final PasyarTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? PasyarColors.accent : PasyarColors.muted;
    return Semantics(
      button: true,
      selected: active,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 3,
          children: [
            Icon(tab.icon, size: 22, color: color),
            Text(
              tab.label,
              style:
                  (active
                          ? PasyarTextStyles.tabLabelActive
                          : PasyarTextStyles.tabLabel)
                      .copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
