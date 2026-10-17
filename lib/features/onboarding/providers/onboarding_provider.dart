import 'package:flutter/foundation.dart';

import '../../../core/location/location_permission.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/avatar_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../onboarding_rules.dart';

/// Holds the onboarding draft across both steps until it is saved.
class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider({
    required AuthProvider auth,
    required AvatarRepository avatars,
    required LocationPermissionService location,
  }) : _auth = auth,
       _avatars = avatars,
       _location = location {
    final p = auth.profile;
    riderName = p?.displayName ?? OnboardingRules.suggestRiderName(p?.fullName);
    bikeType = p?.bikeType;
    homeArea = p?.homeArea ?? '';
    avatarUrl = p?.avatarUrl;
  }

  final AuthProvider _auth;
  final AvatarRepository _avatars;
  final LocationPermissionService _location;

  late String riderName;
  BikeType? bikeType;
  late String homeArea;

  /// Uploaded photo URL, and the local bytes shown while/after uploading.
  String? avatarUrl;
  Uint8List? avatarPreview;
  bool uploadingAvatar = false;
  bool saving = false;

  bool get canContinue =>
      OnboardingRules.riderName(riderName) == null &&
      OnboardingRules.homeArea(homeArea) == null &&
      !uploadingAvatar;

  void setRiderName(String value) {
    riderName = value;
    notifyListeners();
  }

  /// Tapping the selected card again clears it (bike type is optional).
  void toggleBikeType(BikeType type) {
    bikeType = bikeType == type ? null : type;
    notifyListeners();
  }

  void setHomeArea(String value) {
    homeArea = value;
    notifyListeners();
  }

  /// Shows [jpeg] right away and uploads it. Throws if the upload fails
  /// (the preview is cleared again).
  Future<void> setAvatar(Uint8List jpeg) async {
    final userId = _auth.user?.id;
    if (userId == null) return;
    final previousUrl = avatarUrl;
    avatarPreview = jpeg;
    uploadingAvatar = true;
    notifyListeners();
    try {
      avatarUrl = await _avatars.uploadAvatar(userId, jpeg);
    } catch (_) {
      avatarPreview = null;
      avatarUrl = previousUrl;
      rethrow;
    } finally {
      uploadingAvatar = false;
      notifyListeners();
    }
  }

  void removeAvatar() {
    avatarPreview = null;
    avatarUrl = null;
    notifyListeners();
  }

  /// Step 1 → saves the profile fields.
  Future<void> saveProfile() async {
    saving = true;
    notifyListeners();
    try {
      final area = homeArea.trim();
      await _auth.updateProfile({
        'display_name': riderName.trim(),
        'bike_type': bikeType?.value,
        'home_area': area.isEmpty ? null : area,
        'avatar_url': avatarUrl,
      });
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  /// Step 2 → ALLOW LOCATION. Whatever the answer, onboarding finishes; the
  /// Ride tab shows a banner when location is off.
  Future<LocationAccess> allowLocationAndFinish() async {
    final access = await _location.requestWhileInUse();
    await finish();
    return access;
  }

  /// Marks onboarding done; the router then moves on to /ride.
  Future<void> finish() async {
    saving = true;
    notifyListeners();
    try {
      await _auth.updateProfile({'onboarding_completed': true});
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
