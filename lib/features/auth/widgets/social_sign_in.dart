import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';

/// Apple and Google buttons. Apple always goes first. [compact] lays them out
/// side by side (Register). While [busy] is set, that button shows a spinner
/// and taps are blocked without dimming either button.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.busy,
    required this.onApple,
    required this.onGoogle,
    this.compact = false,
  });

  /// Which provider is signing in, or null.
  final SocialProvider? busy;
  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      SocialButton(
        provider: SocialProvider.apple,
        label: compact ? 'Apple' : 'Continue with Apple',
        compact: compact,
        loading: busy == SocialProvider.apple,
        onPressed: onApple,
      ),
      SocialButton(
        provider: SocialProvider.google,
        label: compact ? 'Google' : 'Continue with Google',
        compact: compact,
        loading: busy == SocialProvider.google,
        onPressed: onGoogle,
      ),
    ];
    return AbsorbPointer(
      absorbing: busy != null,
      child: compact
          ? Row(
              spacing: 10,
              children: [for (final b in buttons) Expanded(child: b)],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: buttons,
            ),
    );
  }
}
