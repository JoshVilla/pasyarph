import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../data/models/enums.dart';
import '../../../data/repositories/avatar_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../me/profile_rules.dart';
import '../../onboarding/onboarding_rules.dart';

/// The Edit profile form: name, username, bio, bike, town and picture. The
/// cover is saved on its own ([CoverController]).
class EditProfileController extends ChangeNotifier {
  EditProfileController({
    required AuthProvider auth,
    required AvatarRepository avatars,
  }) : _auth = auth,
       _avatars = avatars {
    final p = auth.profile;
    name = p?.displayName ?? OnboardingRules.suggestRiderName(p?.fullName);
    username = p?.username ?? '';
    bio = p?.bio ?? '';
    bikeType = p?.bikeType;
    homeArea = p?.homeArea ?? '';
    avatarUrl = p?.avatarUrl;
  }

  final AuthProvider _auth;
  final AvatarRepository _avatars;

  static const usernameTaken = 'That username is taken. Try another one.';
  static const saveFailed =
      "Couldn't save your profile. Check your connection and try again.";

  late String name;
  late String username;
  late String bio;
  BikeType? bikeType;
  late String homeArea;
  String? avatarUrl;
  Uint8List? avatarPreview;
  bool uploadingAvatar = false;
  bool saving = false;

  /// From the last save (e.g. the username is taken).
  String? usernameServerError;

  String? get nameError => OnboardingRules.riderName(name);
  String? get usernameErrorText =>
      usernameServerError ?? usernameError(username);
  String? get bioErrorText => bioError(bio);
  String? get homeAreaError => OnboardingRules.homeArea(homeArea);

  bool get canSave =>
      nameError == null &&
      usernameError(username) == null &&
      bioErrorText == null &&
      homeAreaError == null &&
      !uploadingAvatar &&
      !saving;

  void setName(String v) => _set(() => name = v);
  void setUsername(String v) => _set(() {
    username = v;
    usernameServerError = null;
  });
  void setBio(String v) => _set(() => bio = v);
  void setHomeArea(String v) => _set(() => homeArea = v);

  /// Tapping the selected bike again clears it (it's optional).
  void toggleBikeType(BikeType t) =>
      _set(() => bikeType = bikeType == t ? null : t);

  void _set(VoidCallback change) {
    change();
    notifyListeners();
  }

  /// Shows [jpeg] at once and uploads it. Throws if the upload fails (the
  /// old picture comes back).
  Future<void> setAvatar(Uint8List jpeg) async {
    final userId = _auth.user?.id;
    if (userId == null) return;
    final before = avatarUrl;
    avatarPreview = jpeg;
    uploadingAvatar = true;
    notifyListeners();
    try {
      avatarUrl = await _avatars.uploadAvatar(userId, jpeg);
    } catch (_) {
      avatarPreview = null;
      avatarUrl = before;
      rethrow;
    } finally {
      uploadingAvatar = false;
      notifyListeners();
    }
  }

  void removeAvatar() => _set(() {
    avatarPreview = null;
    avatarUrl = null;
  });

  /// Saves the form. Returns why it failed, or null. Check [canSave]
  /// first: a form that can't be saved isn't sent.
  Future<String?> save() async {
    if (!canSave) return saveFailed;
    saving = true;
    notifyListeners();
    try {
      final area = homeArea.trim();
      final about = bio.trim();
      await _auth.updateProfile({
        'display_name': name.trim(),
        'username': normalizeUsername(username),
        'bio': about.isEmpty ? null : about,
        'bike_type': bikeType?.value,
        'home_area': area.isEmpty ? null : area,
        'avatar_url': avatarUrl,
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        usernameServerError = usernameTaken;
        return usernameTaken;
      }
      return saveFailed;
    } on Exception {
      return saveFailed;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
