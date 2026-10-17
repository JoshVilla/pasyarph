import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth_redirect.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/welcome_illustration.dart';

/// Shown whenever the user is signed out. Matches
/// design/screenshots/07-welcome.png.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: PasyarColors.ink,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(child: WelcomeIllustration()),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                math.max(40.0, bottomInset + 16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      'PASYAR',
                      style: PasyarTextStyles.wordmark.copyWith(
                        color: PasyarColors.card,
                      ),
                    ),
                  ),
                  Text(
                    'Walang plano? Pasyar na.',
                    style: PasyarTextStyles.tagline,
                  ),
                  Text(
                    'Generate a motorcycle loop from where you are, ride it, '
                    'and share the stop with other riders.',
                    style: PasyarTextStyles.body.copyWith(
                      fontSize: 16,
                      height: 1.45,
                      color: PasyarColors.onInkMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'CREATE ACCOUNT',
                    onPressed: () => context.push(AuthRoutes.register),
                  ),
                  SecondaryButton.onDark(
                    label: 'I ALREADY HAVE AN ACCOUNT',
                    onPressed: () => context.push(AuthRoutes.login),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
