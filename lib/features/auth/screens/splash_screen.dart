import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

/// Shown while a signed-in user's profile loads, or if loading failed.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.status != AuthStatus.profileError) {
      return const Scaffold(
        backgroundColor: PasyarColors.card,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AuthScaffold(
      leading: const AuthIconBadge(icon: LucideIcons.cloudOff),
      title: "COULDN'T LOAD YOUR PROFILE",
      subtitle: 'Check your connection and try again.',
      bottom: [
        PrimaryButton(label: 'TRY AGAIN', onPressed: auth.reloadProfile),
        AuthFooterLink(text: '', link: 'Log out', onTap: auth.signOut),
      ],
      children: const [],
    );
  }
}
