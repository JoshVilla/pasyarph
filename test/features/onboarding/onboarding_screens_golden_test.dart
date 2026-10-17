import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/features/auth/providers/auth_provider.dart';
import 'package:pasyarph/features/onboarding/providers/onboarding_provider.dart';
import 'package:pasyarph/features/onboarding/screens/onboarding_location_screen.dart';
import 'package:pasyarph/features/onboarding/screens/onboarding_profile_screen.dart';
import 'package:provider/provider.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_services.dart';

/// Compare with design/screenshots/10-onboarding-profile.png and
/// 11-onboarding-location.png.
const _screen = BoxConstraints.tightFor(width: 390, height: 844);

Widget _withDraft(Widget screen) {
  final auth = AuthProvider(FakeAuthRepository());
  final draft =
      OnboardingProvider(
          auth: auth,
          avatars: FakeAvatarRepository(),
          location: FakeLocationPermission(),
        )
        ..setRiderName('Juan')
        ..toggleBikeType(BikeType.underbone);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: draft),
    ],
    child: screen,
  );
}

void main() {
  group('Golden', () {
    goldenTest(
      'Onboarding step 1 (10)',
      fileName: 'onboarding_profile',
      constraints: _screen,
      builder: () => _withDraft(const OnboardingProfileScreen()),
    );

    goldenTest(
      'Onboarding step 2 (11)',
      fileName: 'onboarding_location',
      constraints: _screen,
      builder: () => _withDraft(const OnboardingLocationScreen()),
    );
  });
}
