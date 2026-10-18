import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import 'bottom_tabs.dart';

/// Tab index of Create in [pasyarTabs]. Create isn't a branch: it opens the
/// full-screen Create a loop screen over the tabs (design/mockups/06).
const createTab = 2;

/// Bottom navigation shell for the four main tabs: Ride, Feed, Create, Me.
/// Branches are the tabs without Create, in order (see `createRouter()`).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static int tabFor(int branch) => branch >= createTab ? branch + 1 : branch;
  static int branchFor(int tab) => tab > createTab ? tab - 1 : tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: PasyarBottomTabs(
        currentIndex: tabFor(shell.currentIndex),
        onTap: (tab) {
          if (tab == createTab) {
            context.push(Routes.create);
            return;
          }
          final branch = branchFor(tab);
          shell.goBranch(
            branch,
            // Tapping the active tab again returns to its first screen.
            initialLocation: branch == shell.currentIndex,
          );
        },
      ),
    );
  }
}
