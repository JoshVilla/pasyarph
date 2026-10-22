import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/club.dart';
import '../../../data/repositories/club_repository.dart';
import '../../auth/widgets/auth_scaffold.dart';
import '../../onboarding/avatar_image.dart';
import '../../onboarding/widgets/avatar_picker.dart';
import '../../onboarding/widgets/photo_source_sheet.dart';
import '../club_rules.dart';

/// New club: optional photo and a name. Opens the club when it's made.
class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({super.key});

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  final _name = TextEditingController();
  Uint8List? _photo;
  bool _nameTouched = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final choice = await showPhotoSourceSheet(
      context,
      canRemove: _photo != null,
    );
    if (choice == null) return;
    final source = imageSourceFor(choice);
    if (source == null) {
      setState(() => _photo = null);
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
      if (mounted) {
        setState(() {
          _photo = jpeg;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = "Couldn't add that photo. Try another one.");
      }
    }
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final club = await context.read<ClubRepository>().create(
        _name.text,
        photoJpeg: _photo,
      );
      if (mounted) context.pushReplacement(Routes.club(club.id));
    } on ClubException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moving = context.watch<LocationProvider>().isMoving;
    final nameError = _nameTouched ? clubNameError(_name.text) : null;
    final canCreate = clubNameError(_name.text) == null && !_saving && !moving;

    return AuthScaffold(
      title: 'NEW CLUB',
      subtitle: 'Ride together. Share loops only your club can see.',
      onBack: () => context.pop(),
      bottom: [
        AuthErrorText(
          _error ?? (moving ? 'Stop riding to make a club.' : null),
        ),
        PrimaryButton(
          label: 'CREATE CLUB',
          loading: _saving,
          onPressed: canCreate ? _create : null,
        ),
      ],
      children: [
        Row(
          spacing: 16,
          children: [
            AvatarPicker(
              onTap: _saving ? null : _pickPhoto,
              preview: _photo,
              icon: LucideIcons.users,
              what: 'club photo',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    'Add a club photo',
                    style: PasyarTextStyles.bodyLarge.copyWith(fontSize: 16),
                  ),
                  Text(
                    'A logo or a group shot. Optional.',
                    style: PasyarTextStyles.label.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        Focus(
          onFocusChange: (focused) {
            if (!focused && _name.text.isNotEmpty) {
              setState(() => _nameTouched = true);
            }
          },
          child: PasyarTextField(
            label: 'Club name',
            hint: 'e.g. Cordon Riders',
            controller: _name,
            error: nameError,
            enabled: !_saving && !moving,
            maxLength: Club.maxName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              setState(() => _nameTouched = true);
              if (canCreate) _create();
            },
          ),
        ),
      ],
    );
  }
}
