import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/env.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Placeholder for the Me tab.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PasyarSpacing.sheet),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: PasyarSpacing.groupGap,
            children: [
              const Text('Me'),
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
