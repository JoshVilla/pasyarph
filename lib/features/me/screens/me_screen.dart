import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/env.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/providers/auth_provider.dart';

/// Placeholder for the Me tab (Prompt 19 builds the real profile).
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.profile?.displayName ?? auth.profile?.fullName;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PasyarSpacing.sheet),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: PasyarSpacing.groupGap,
            children: [
              Text(
                name ?? 'Me',
                textAlign: TextAlign.center,
                style: PasyarTextStyles.screenTitle(32),
              ),
              if (auth.user?.email != null)
                Text(
                  auth.user!.email!,
                  textAlign: TextAlign.center,
                  style: PasyarTextStyles.label,
                ),
              SecondaryButton(label: 'LOG OUT', onPressed: auth.signOut),
              if (Env.isDev)
                SecondaryButton(
                  label: 'WIDGET GALLERY',
                  onPressed: () => context.push(Routes.devWidgets),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
