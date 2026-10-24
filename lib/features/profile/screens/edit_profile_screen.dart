import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../auth/widgets/auth_scaffold.dart' show AuthErrorText;
import '../../me/profile_rules.dart';
import '../../onboarding/avatar_image.dart';
import '../../onboarding/widgets/photo_source_sheet.dart';
import '../edit_cover.dart';
import '../providers/cover_controller.dart';
import '../providers/edit_profile_controller.dart';
import '../widgets/profile_cover.dart';

/// Me → Edit profile: cover and picture at the top, then name, username
/// (asked for when missing), bio, bike and town. SAVE stays above the
/// keyboard. Expects an [EditProfileController] above it.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.pick});

  /// Replaceable in tests (the cover picker).
  final PickPhoto? pick;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileController _form = context
      .read<EditProfileController>();
  late final _name = TextEditingController(text: _form.name);
  late final _username = TextEditingController(text: _form.username);
  late final _bio = TextEditingController(text: _form.bio);
  late final _area = TextEditingController(text: _form.homeArea);
  bool _touched = false;
  String? _error;

  static const _bikes = [
    (BikeType.scooter, 'SCOOTER', 'scooter'),
    (BikeType.underbone, 'UNDERBONE', 'underbone'),
    (BikeType.bigBike, 'BIG BIKE', 'big-bike'),
    (BikeType.dualSport, 'DUAL-SPORT', 'dual-sport'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _area.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go(Routes.me);

  Future<void> _pickAvatar() async {
    final hasPhoto = _form.avatarPreview != null || _form.avatarUrl != null;
    final choice = await showPhotoSourceSheet(context, canRemove: hasPhoto);
    if (choice == null) return;
    final source = imageSourceFor(choice);
    if (source == null) return _form.removeAvatar();
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
      await _form.setAvatar(jpeg);
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't add that photo. Try another one.");
      }
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _touched = true;
      _error = null;
    });
    // Shows what to fix under each field instead of saving.
    if (!_form.canSave) return;
    final error = await _form.save();
    if (!mounted) return;
    if (error != null) {
      // A taken username shows under its field.
      if (error != EditProfileController.usernameTaken) {
        setState(() => _error = error);
      }
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Profile saved.')));
    _back();
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<EditProfileController>();
    final covers = context.watch<CoverController>();
    final feed = context.read<FeedRepository>();
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom > 0;
    final avatar = form.avatarPreview != null
        ? MemoryImage(form.avatarPreview!)
        : form.avatarUrl != null
        ? feed.avatar(form.avatarUrl!)
        : null;

    return Scaffold(
      backgroundColor: PasyarColors.card,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 44),
                      child: ProfileCover(
                        image: covers.coverUrl == null
                            ? null
                            : feed.avatar(covers.coverUrl!),
                        busy: covers.busy,
                        leading: CoverIconButton(
                          icon: LucideIcons.chevronLeft,
                          label: 'Back',
                          onPressed: _back,
                        ),
                        onEditCover: () => editCover(
                          context,
                          pick: widget.pick ?? _defaultPick,
                        ),
                      ),
                    ),
                    Positioned(
                      left: PasyarSpacing.screen,
                      bottom: 0,
                      child: _AvatarEditor(
                        name: form.name.isEmpty ? 'Me' : form.name,
                        image: avatar,
                        uploading: form.uploadingAvatar,
                        onTap: form.uploadingAvatar ? null : _pickAvatar,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 20,
                    children: [
                      Text(
                        'EDIT PROFILE',
                        style: PasyarTextStyles.screenTitle(30),
                      ),
                      PasyarTextField(
                        label: 'Rider name',
                        controller: _name,
                        error: _touched ? form.nameError : null,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        onChanged: form.setName,
                      ),
                      PasyarTextField(
                        label: 'Username',
                        controller: _username,
                        prefixText: '@',
                        hint: 'ana.rides',
                        error:
                            form.usernameServerError ??
                            (_touched || form.username.isNotEmpty
                                ? usernameError(form.username)
                                : null),
                        helper: 'Letters, numbers, dots and underscores.',
                        maxLength: 21,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        onChanged: form.setUsername,
                      ),
                      PasyarTextField(
                        label: 'Bio',
                        controller: _bio,
                        hint: 'What and where you like to ride.',
                        maxLines: 4,
                        maxLength: maxBio,
                        error: form.bioErrorText,
                        helper: '${form.bio.trim().length} / $maxBio',
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: form.setBio,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 8,
                        children: [
                          Text(
                            'What do you ride?',
                            style: PasyarTextStyles.fieldLabel,
                          ),
                          for (var row = 0; row < _bikes.length; row += 2)
                            Row(
                              spacing: 10,
                              children: [
                                for (final (type, label, picture)
                                    in _bikes.skip(row).take(2))
                                  Expanded(
                                    child: ChoiceCard(
                                      title: label,
                                      image: AssetImage(
                                        'assets/motorcycles/cards/$picture.png',
                                      ),
                                      selected: form.bikeType == type,
                                      onTap: () => form.toggleBikeType(type),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      PasyarTextField(
                        label: 'Home area',
                        hint: 'e.g. Cordon, Isabela',
                        controller: _area,
                        error: form.homeAreaError,
                        helper: 'Town only. Helps show loops near you.',
                        textCapitalization: TextCapitalization.words,
                        onChanged: form.setHomeArea,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              keyboard ? 8 : math.max(20, media.viewPadding.bottom + 12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthErrorText(_error),
                PrimaryButton(
                  label: 'SAVE',
                  loading: form.saving,
                  onPressed: form.uploadingAvatar || form.saving ? null : _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List?> _defaultPick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 3000,
      maxHeight: 3000,
      imageQuality: 95,
    );
    return file?.readAsBytes();
  }
}

/// The 84 px rounded-square picture with a camera badge.
class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.name,
    required this.image,
    required this.uploading,
    required this.onTap,
  });

  final String name;
  final ImageProvider? image;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Change profile picture',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: PasyarColors.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: PasyarShadows.floating,
              ),
              child: Avatar(name: name, image: image, size: 76, radius: 20),
            ),
            if (uploading)
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(color: PasyarColors.card),
                ),
              ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: PasyarColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: PasyarColors.card, width: 2),
                ),
                child: const Icon(
                  LucideIcons.camera,
                  size: 15,
                  color: PasyarColors.card,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
