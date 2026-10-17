import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pasyarph/core/theme/pasyar_theme.dart';
import 'package:pasyarph/core/widgets/widgets.dart';

/// Rebuilds parts of the mockups from the shared widgets only, to compare
/// against design/screenshots/ and catch drift in the components. These are
/// not the real screens (those come with their own prompts).
void main() {
  group('Golden', () {
    goldenTest(
      'Home sheet from shared widgets (compare 01-home.png)',
      fileName: 'compose_home_sheet',
      builder: () => GoldenTestGroup(
        children: [
          GoldenTestScenario(
            name: 'home sheet + tabs',
            child: SizedBox(
              width: 390,
              child: ColoredBox(
                color: PasyarColors.mapGround,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    BottomSheetPanel(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text(
                              'WHERE TO TODAY?',
                              style: PasyarTextStyles.screenTitle(30),
                            ),
                            Text(
                              "Pick how long. We'll make the loop.",
                              style: PasyarTextStyles.body.copyWith(
                                height: 1.2,
                                color: PasyarColors.muted,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          spacing: 10,
                          children: [
                            Expanded(
                              child: ChoiceCard(
                                title: 'QUICK',
                                subtitle: 'about 1 hr',
                                selected: false,
                                onTap: () {},
                              ),
                            ),
                            Expanded(
                              child: ChoiceCard(
                                title: 'HALF-DAY',
                                subtitle: 'about 4 hr',
                                selected: true,
                                onTap: () {},
                              ),
                            ),
                            Expanded(
                              child: ChoiceCard(
                                title: 'FULL DAY',
                                subtitle: '6 hr +',
                                selected: false,
                                onTap: () {},
                              ),
                            ),
                          ],
                        ),
                        Row(
                          spacing: 10,
                          children: [
                            Expanded(
                              child: PillToggle(
                                label: 'Avoid highways',
                                value: true,
                                onChanged: (_) {},
                              ),
                            ),
                            Expanded(
                              child: PillToggle(
                                label: 'Avoid unpaved',
                                value: false,
                                onChanged: (_) {},
                              ),
                            ),
                          ],
                        ),
                        PrimaryButton(
                          label: 'GENERATE LOOP',
                          icon: LucideIcons.rotateCw,
                          onPressed: () {},
                        ),
                      ],
                    ),
                    PasyarBottomTabs(currentIndex: 0, onTap: (_) {}),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'Log in form from shared widgets (compare 08-login.png)',
      fileName: 'compose_login',
      builder: () => GoldenTestGroup(
        children: [
          GoldenTestScenario(
            name: 'log in',
            child: Material(
              color: PasyarColors.card,
              child: SizedBox(
                width: 390,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 20,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RoundIconButton.ground(
                          icon: LucideIcons.chevronLeft,
                          semanticLabel: 'Back',
                          onPressed: () {},
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          Text(
                            'WELCOME BACK',
                            style: PasyarTextStyles.screenTitle(36),
                          ),
                          Text(
                            'Log in to keep riding.',
                            style: PasyarTextStyles.body.copyWith(
                              fontSize: 16,
                              height: 1.2,
                              color: PasyarColors.muted,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        spacing: 10,
                        children: [
                          SocialButton(
                            provider: SocialProvider.apple,
                            label: 'Continue with Apple',
                            onPressed: () {},
                          ),
                          SocialButton(
                            provider: SocialProvider.google,
                            label: 'Continue with Google',
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const OrDivider(text: 'or log in with email'),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 14,
                        children: [
                          const PasyarTextField(
                            label: 'Email',
                            hint: 'you@email.com',
                          ),
                          PasyarTextField(
                            label: 'Password',
                            password: true,
                            controller: TextEditingController(
                              text: 'password123',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  });
}
