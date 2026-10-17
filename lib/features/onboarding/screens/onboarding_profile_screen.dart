import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/auth_redirect.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/enums.dart';
import '../../auth/auth_errors.dart';
import '../../auth/widgets/auth_scaffold.dart';
import '../avatar_image.dart';
import '../onboarding_rules.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/photo_source_sheet.dart';

/// Step 1 — rider profile. Matches
/// design/screenshots/10-onboarding-profile.png.
class OnboardingProfileScreen extends StatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  State<OnboardingProfileScreen> createState() =>
      _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends State<OnboardingProfileScreen> {
  late final OnboardingProvider _draft = context.read<OnboardingProvider>();
  late final _name = TextEditingController(text: _draft.riderName);
  late final _area = TextEditingController(text: _draft.homeArea);
  bool _nameTouched = false;
  String? _error;

  static const _bikes = [
    (BikeType.scooter, 'SCOOTER'),
    (BikeType.underbone, 'UNDERBONE'),
    (BikeType.bigBike, 'BIG BIKE'),
    (BikeType.dualSport, 'DUAL-SPORT'),
  ];

  Future<void> _pickPhoto() async {
    final hasPhoto = _draft.avatarPreview != null || _draft.avatarUrl != null;
    final choice = await showPhotoSourceSheet(context, canRemove: hasPhoto);
    if (choice == null) return;
    final source = imageSourceFor(choice);
    if (source == null) {
      _draft.removeAvatar();
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (file == null) return;
      final jpeg = await compute(squareAvatarJpeg, await file.readAsBytes());
      setState(() => _error = null);
      await _draft.setAvatar(jpeg);
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Couldn't add that photo. Try another one.");
      }
    }
  }

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    try {
      await _draft.saveProfile();
      if (mounted) context.push(AuthRoutes.onboardingLocation);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyAuthError(e));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<OnboardingProvider>();
    final nameError = _nameTouched
        ? OnboardingRules.riderName(draft.riderName)
        : null;

    return AuthScaffold(
      top: 60,
      titleSize: 34,
      titleHeight: 1.05,
      leading: const StepProgress(step: 1, total: 2),
      title: 'SET UP YOUR\nRIDER PROFILE',
      bottom: [
        AuthErrorText(_error),
        PrimaryButton(
          label: 'NEXT',
          loading: draft.saving,
          onPressed: draft.canContinue ? _next : null,
        ),
      ],
      children: [
        Row(
          spacing: 16,
          children: [
            AvatarPicker(
              onTap: draft.uploadingAvatar ? null : _pickPhoto,
              preview: draft.avatarPreview,
              url: draft.avatarUrl,
              uploading: draft.uploadingAvatar,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    'Add a photo',
                    style: PasyarTextStyles.bodyLarge.copyWith(fontSize: 16),
                  ),
                  Text(
                    'Riders trust faces in the feed. Optional.',
                    style: PasyarTextStyles.label.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        PasyarTextField(
          label: 'Rider name',
          controller: _name,
          error: nameError,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.nickname],
          onChanged: (v) {
            _nameTouched = true;
            draft.setRiderName(v);
          },
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            Text('What do you ride?', style: PasyarTextStyles.fieldLabel),
            Column(
              spacing: 10,
              children: [
                for (var row = 0; row < _bikes.length; row += 2)
                  Row(
                    spacing: 10,
                    children: [
                      for (final (type, label) in _bikes.skip(row).take(2))
                        Expanded(
                          child: ChoiceCard(
                            title: label,
                            selected: draft.bikeType == type,
                            onTap: () => draft.toggleBikeType(type),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        PasyarTextField(
          label: 'Home area',
          hint: 'e.g. Cordon, Isabela',
          controller: _area,
          error: OnboardingRules.homeArea(draft.homeArea),
          helper: 'Town only. Helps show loops near you.',
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onChanged: draft.setHomeArea,
          onSubmitted: (_) => draft.canContinue ? _next() : null,
        ),
      ],
    );
  }
}
