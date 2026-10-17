import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/auth_redirect.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/auth_errors.dart';
import '../../auth/widgets/auth_scaffold.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/location_illustration.dart';

/// Step 2 — location + safety. Matches
/// design/screenshots/11-onboarding-location.png.
class OnboardingLocationScreen extends StatefulWidget {
  const OnboardingLocationScreen({super.key});

  @override
  State<OnboardingLocationScreen> createState() =>
      _OnboardingLocationScreenState();
}

class _OnboardingLocationScreenState extends State<OnboardingLocationScreen> {
  String? _error;
  bool _asking = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _error = null);
    try {
      await action();
      // The router moves on to /ride once onboarding is marked done.
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    }
  }

  Future<void> _allow() async {
    setState(() => _asking = true);
    await _run(
      () => context.read<OnboardingProvider>().allowLocationAndFinish(),
    );
    if (mounted) setState(() => _asking = false);
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<OnboardingProvider>();
    final busy = draft.saving || _asking;

    return AuthScaffold(
      top: 60,
      titleSize: 34,
      subtitleGap: 6,
      subtitleHeight: 1.45,
      leading: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 20,
        children: [
          Row(
            spacing: 12,
            children: [
              RoundIconButton.ground(
                icon: LucideIcons.chevronLeft,
                semanticLabel: 'Back',
                onPressed: busy
                    ? null
                    : () => context.canPop()
                          ? context.pop()
                          : context.go(AuthRoutes.onboardingProfile),
              ),
              const Expanded(child: StepProgress(step: 2, total: 2)),
            ],
          ),
          const Center(child: LocationIllustration()),
        ],
      ),
      title: 'TURN ON LOCATION',
      subtitle:
          'Pasyar builds loops from where you are and guides you turn by turn.',
      // "Not now" has a 44 px tap area; keep its text where the mockup has it.
      bottomTrim: 3,
      bottom: [
        AuthErrorText(_error),
        PrimaryButton(
          label: 'ALLOW LOCATION',
          icon: LucideIcons.locate,
          loading: busy,
          onPressed: _allow,
        ),
        const SizedBox(height: 7),
        Center(
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: busy ? null : () => _run(draft.finish),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 44,
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      'Not now',
                      style: PasyarTextStyles.bodyStrong.copyWith(height: 1.2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      children: const [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            SafetyRow(
              icon: LucideIcons.shield,
              lead: 'Your start stays private.',
              text: ' Shared routes hide the first and last 800 m.',
            ),
            SafetyRow(
              icon: LucideIcons.smartphone,
              lead: 'Mount your phone',
              text: ' before you ride.',
            ),
            SafetyRow(
              icon: LucideIcons.lock,
              lead: 'Typing locks while moving.',
              text: ' Post when you stop.',
            ),
          ],
        ),
      ],
    );
  }
}
