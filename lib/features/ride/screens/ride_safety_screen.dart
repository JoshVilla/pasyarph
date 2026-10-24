import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/settings/app_settings.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/widgets/auth_scaffold.dart';

/// Shown once, before the first START RIDE: mount the phone, hands off
/// while moving, ride within your limits. Pops true when the rider is
/// ready (and remembers it), false on Back.
class RideSafetyScreen extends StatelessWidget {
  const RideSafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'BEFORE YOUR\nFIRST RIDE',
      titleHeight: 1.05,
      subtitle: 'A few things to keep every loop a good one.',
      onBack: () => context.pop(false),
      bottom: [
        PrimaryButton(
          label: "GOT IT, LET'S RIDE",
          icon: LucideIcons.bike,
          onPressed: () async {
            await context.read<AppSettings>().setFirstRideSafetySeen();
            if (context.mounted) context.pop(true);
          },
        ),
      ],
      children: const [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            SafetyRow(
              icon: LucideIcons.smartphone,
              lead: 'Mount your phone',
              text: ' on the handlebar before you start. Never hold it while '
                  'riding.',
            ),
            SafetyRow(
              icon: LucideIcons.lock,
              lead: 'Hands off while moving.',
              text: ' Typing and posting lock above 10 km/h. Voice prompts '
                  'tell you when you reach the stop.',
            ),
            SafetyRow(
              icon: LucideIcons.gauge,
              lead: 'Ride within your limits.',
              text: " Loops can have steep, narrow or rough roads. Slow down, "
                  "and turn back if it doesn't feel right.",
            ),
            SafetyRow(
              icon: LucideIcons.hardHat,
              lead: 'Gear up.',
              text: ' Helmet, closed shoes and lights on. Tell someone where '
                  "you're riding.",
            ),
            SafetyRow(
              icon: LucideIcons.fuel,
              lead: 'Check fuel and weather.',
              text: ' Fill up before long loops; skip mountain roads in heavy '
                  'rain.',
            ),
          ],
        ),
      ],
    );
  }
}
