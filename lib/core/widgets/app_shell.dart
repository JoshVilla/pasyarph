import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'bottom_tabs.dart';

/// Bottom navigation shell for the four main tabs: Ride, Feed, Create, Me.
/// Branch order must match the branches in `createRouter()`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: PasyarBottomTabs(
        currentIndex: shell.currentIndex,
        onTap: (index) => shell.goBranch(
          index,
          // Tapping the active tab again returns to its first screen.
          initialLocation: index == shell.currentIndex,
        ),
      ),
    );
  }
}
