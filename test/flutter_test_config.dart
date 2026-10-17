import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:pasyarph/core/theme/pasyar_theme.dart';

/// Golden tests render with the real bundled fonts (platform goldens) so they
/// can be compared with design/screenshots/. Update them with
/// `flutter test --update-goldens`.
Future<void> testExecutable(FutureOr<void> Function() testMain) {
  return AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      theme: PasyarTheme.light(),
      platformGoldensConfig: const PlatformGoldensConfig(),
      ciGoldensConfig: const CiGoldensConfig(enabled: false),
    ),
    run: () async => testMain(),
  );
}
