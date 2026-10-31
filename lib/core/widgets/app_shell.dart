import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import 'bottom_tabs.dart';

/// Tab index of Create in [pasyarTabs]. Create isn't a branch: it opens the
/// full-screen Create a loop screen over the tabs (design/mockups/06).
const createTab = 2;

/// Branch index of Feed (the first tab).
const feedBranch = 0;

/// Taps on the tab that's already open, for its screen to react (the Feed
/// scrolls back to the top). [branch] is the tapped branch.
class TabReselects extends ChangeNotifier {
  int? branch;

  void reselect(int b) {
    branch = b;
    notifyListeners();
  }
}

final tabReselects = TabReselects();

/// Bottom navigation shell for the four main tabs: Feed, Ride, Create, Me.
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
          if (branch == shell.currentIndex) tabReselects.reselect(branch);
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
