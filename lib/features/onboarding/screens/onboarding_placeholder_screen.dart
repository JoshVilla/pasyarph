import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/widgets.dart';
import '../../auth/auth_errors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/widgets/auth_scaffold.dart';

/// Stand-in for /onboarding/profile until Prompt 05 builds the real rider
/// profile and location steps. CONTINUE marks onboarding as done.
class OnboardingPlaceholderScreen extends StatefulWidget {
  const OnboardingPlaceholderScreen({super.key});

  @override
  State<OnboardingPlaceholderScreen> createState() =>
      _OnboardingPlaceholderScreenState();
}

class _OnboardingPlaceholderScreenState
    extends State<OnboardingPlaceholderScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _finish() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().updateProfile({
        'onboarding_completed': true,
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final name = auth.profile?.fullName;
    return AuthScaffold(
      title: 'WELCOME, RIDER',
      subtitle: [
        if (name != null) 'Signed in as $name.',
        'Rider profile setup comes next.',
      ].join(' '),
      bottom: [
        AuthErrorText(_error),
        PrimaryButton(label: 'CONTINUE', loading: _loading, onPressed: _finish),
        AuthFooterLink(text: '', link: 'Log out', onTap: auth.signOut),
      ],
      children: const [],
    );
  }
}
