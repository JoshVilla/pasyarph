import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pasyarph/core/theme/pasyar_theme.dart';
import 'package:pasyarph/core/widgets/widgets.dart';
import 'package:pasyarph/features/dev/screens/widget_gallery_screen.dart';

/// Content width inside a 390 px screen with 20 px padding.
const _width = 350.0;

Widget _frame(Widget child, {double width = _width, Color? color}) => Material(
  color: color ?? PasyarColors.card,
  child: Padding(
    padding: const EdgeInsets.all(8),
    child: SizedBox(width: width, child: child),
  ),
);

GoldenTestScenario _scenario(
  String name,
  Widget child, {
  double width = _width,
  Color? color,
}) => GoldenTestScenario(
  name: name,
  child: _frame(child, width: width, color: color),
);

void main() {
  group('Golden', () {
    goldenTest(
      'PrimaryButton',
      fileName: 'primary_button',
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'with icon',
            PrimaryButton(
              label: 'GENERATE LOOP',
              icon: LucideIcons.rotateCw,
              onPressed: () {},
            ),
          ),
          _scenario(
            'label only',
            PrimaryButton(label: 'LOG IN', onPressed: () {}),
          ),
          _scenario(
            'disabled',
            const PrimaryButton(label: 'GENERATE LOOP', onPressed: null),
          ),
          _scenario(
            'loading',
            PrimaryButton(label: 'LOG IN', onPressed: () {}, loading: true),
          ),
        ],
      ),
      pumpBeforeTest: pumpOnce,
    );

    goldenTest(
      'SecondaryButton',
      fileName: 'secondary_button',
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'with icon',
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 132,
                child: SecondaryButton(
                  label: 'SHUFFLE',
                  icon: LucideIcons.shuffle,
                  onPressed: () {},
                ),
              ),
            ),
          ),
          _scenario(
            'label only',
            SecondaryButton(label: 'END RIDE', onPressed: () {}),
          ),
          _scenario(
            'disabled',
            const SecondaryButton(label: 'SAVE', onPressed: null),
          ),
          _scenario(
            'on dark',
            SecondaryButton.onDark(
              label: 'I ALREADY HAVE AN ACCOUNT',
              onPressed: () {},
            ),
            color: PasyarColors.ink,
          ),
        ],
      ),
    );

    goldenTest(
      'RoundIconButton and FloatingPill',
      fileName: 'floating_controls',
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'floating',
            Row(
              spacing: 12,
              children: [
                RoundIconButton.floating(
                  icon: LucideIcons.chevronLeft,
                  semanticLabel: 'Back',
                  onPressed: () {},
                ),
                FloatingPill(
                  child: Text(
                    'HALF-DAY LOOP',
                    style: PasyarTextStyles.pillTitle,
                  ),
                ),
              ],
            ),
            width: 358,
            color: PasyarColors.mapGround,
          ),
          _scenario(
            'starting from',
            Row(
              spacing: 12,
              children: [
                const Expanded(child: StartingFromPill()),
                RoundIconButton.floating(
                  icon: LucideIcons.user,
                  semanticLabel: 'Profile',
                  onPressed: () {},
                ),
              ],
            ),
            width: 358,
            color: PasyarColors.mapGround,
          ),
          _scenario(
            'ground',
            Row(
              spacing: 8,
              children: [
                RoundIconButton.ground(
                  icon: LucideIcons.chevronLeft,
                  semanticLabel: 'Back',
                  onPressed: () {},
                ),
                RoundIconButton.ground(
                  icon: LucideIcons.search,
                  iconSize: 20,
                  semanticLabel: 'Search',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'ChoiceCard',
      fileName: 'choice_card',
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'duration',
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
          ),
          _scenario(
            'bike type',
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: ChoiceCard(
                    title: 'SCOOTER',
                    selected: false,
                    onTap: () {},
                  ),
                ),
                Expanded(
                  child: ChoiceCard(
                    title: 'UNDERBONE',
                    selected: true,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'PillToggle',
      fileName: 'pill_toggle',
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'on and off',
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
          ),
        ],
      ),
    );

    goldenTest(
      'PasyarFilterChip',
      fileName: 'filter_chip',
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'selected and unselected',
            Row(
              spacing: PasyarSpacing.chipGap,
              children: [
                PasyarFilterChip(
                  label: 'Near you',
                  selected: true,
                  onTap: () {},
                ),
                PasyarFilterChip(
                  label: 'Following',
                  selected: false,
                  onTap: () {},
                ),
                PasyarFilterChip(
                  label: 'My clubs',
                  selected: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'PasyarTextField',
      fileName: 'text_field',
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'hint',
            const PasyarTextField(label: 'Email', hint: 'you@email.com'),
          ),
          _scenario(
            'filled',
            PasyarTextField(
              label: 'Rider name',
              controller: TextEditingController(text: 'Juan'),
            ),
          ),
          _scenario(
            'password',
            PasyarTextField(
              label: 'Password',
              password: true,
              controller: TextEditingController(text: 'password123'),
            ),
          ),
          _scenario(
            'helper',
            const PasyarTextField(
              label: 'Home area',
              hint: 'e.g. Cordon, Isabela',
              helper: 'Town only. Helps show loops near you.',
            ),
          ),
          _scenario(
            'error',
            PasyarTextField(
              label: 'Password',
              password: true,
              controller: TextEditingController(text: 'short'),
              error: 'Use at least 8 characters.',
            ),
          ),
          _scenario(
            'disabled',
            PasyarTextField(
              label: 'Caption',
              enabled: false,
              controller: TextEditingController(text: 'Locked while moving'),
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'SocialButton',
      fileName: 'social_button',
      pumpBeforeTest: pumpOnce,
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'full width',
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
          ),
          _scenario(
            'half width',
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: SocialButton(
                    provider: SocialProvider.apple,
                    label: 'Apple',
                    compact: true,
                    onPressed: () {},
                  ),
                ),
                Expanded(
                  child: SocialButton(
                    provider: SocialProvider.google,
                    label: 'Google',
                    compact: true,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
          _scenario(
            'loading and disabled',
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: SocialButton(
                    provider: SocialProvider.apple,
                    label: 'Apple',
                    compact: true,
                    loading: true,
                    onPressed: () {},
                  ),
                ),
                const Expanded(
                  child: SocialButton(
                    provider: SocialProvider.google,
                    label: 'Google',
                    compact: true,
                    onPressed: null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'OrDivider and StepProgress',
      fileName: 'divider_step_progress',
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'or divider',
            const OrDivider(text: 'or log in with email'),
          ),
          _scenario('step 1 of 2', const StepProgress(step: 1, total: 2)),
          _scenario('step 2 of 2', const StepProgress(step: 2, total: 2)),
        ],
      ),
    );

    goldenTest(
      'SafetyRow',
      fileName: 'safety_row',
      builder: () => GoldenTestGroup(
        children: [_scenario('onboarding rows', const SafetyRows())],
      ),
    );

    goldenTest(
      'StatBlock and StopCard',
      fileName: 'stats_stop_card',
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'stat row',
            const StatRow(
              children: [
                StatBlock(label: 'Distance', value: '118 km'),
                StatBlock(label: 'Ride time', value: '3 h 50'),
                StatBlock(
                  label: 'Curvy roads',
                  value: 'High',
                  valueColor: PasyarColors.accentDark,
                ),
              ],
            ),
          ),
          _scenario(
            'small values',
            const StatRow(
              children: [
                StatBlock(label: 'Distance', value: '96 km', small: true),
                StatBlock(label: 'Ride time', value: '3 h 10', small: true),
                StatBlock(label: 'Curvy', value: 'Medium', small: true),
              ],
            ),
          ),
          _scenario(
            'stop card',
            const StopCard(
              overline: 'Main stop · 52 km in',
              name: '[Stop name] Viewpoint',
              detail: 'Photo spot · gas station nearby',
            ),
          ),
        ],
      ),
    );

    goldenTest(
      'Avatar',
      fileName: 'avatar',
      builder: () => GoldenTestGroup(
        children: [_scenario('sizes and colors', const AvatarSamples())],
      ),
    );

    goldenTest(
      'BottomSheetPanel and BottomTabs',
      fileName: 'sheet_tabs',
      builder: () => GoldenTestGroup(
        children: [
          _scenario(
            'sheet',
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: BottomSheetPanel(
                children: [Text('Sheet content'), Text('16 px between groups')],
              ),
            ),
            width: 390,
            color: PasyarColors.mapGround,
          ),
          _scenario(
            'tabs',
            PasyarBottomTabs(currentIndex: 0, onTap: (_) {}),
            width: 390,
          ),
        ],
      ),
    );
  });
}
