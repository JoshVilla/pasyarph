import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/env.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/ride_history_list.dart';

/// The Me tab: name, your rides (post the ones from the last 7 days), and
/// log out. Prompt 19 builds the real profile.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.profile?.displayName ?? auth.profile?.fullName;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          PasyarSpacing.sheet,
          pad.top + PasyarSpacing.floatingTop + 12,
          PasyarSpacing.sheet,
          PasyarSpacing.sheet,
        ),
        children: [
          Text(name ?? 'Me', style: PasyarTextStyles.screenTitle(32)),
          if (auth.user?.email != null)
            Text(auth.user!.email!, style: PasyarTextStyles.label),
          const SizedBox(height: 24),
          const RideHistoryList(),
          const SizedBox(height: 32),
          SecondaryButton(label: 'LOG OUT', onPressed: auth.signOut),
          if (Env.isDev) ...[
            const SizedBox(height: PasyarSpacing.buttonGap),
            SecondaryButton(
              label: 'WIDGET GALLERY',
              onPressed: () => context.push(Routes.devWidgets),
            ),
          ],
        ],
      ),
    );
  }
}
