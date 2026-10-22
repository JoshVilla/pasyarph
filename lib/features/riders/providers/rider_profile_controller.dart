import 'package:flutter/foundation.dart';

import '../../../data/models/profile.dart';
import '../../../data/repositories/social_repository.dart';

/// Another rider's profile and the Follow button.
class RiderProfileController extends ChangeNotifier {
  RiderProfileController({
    required SocialRepository social,
    required this.userId,
  }) : _social = social;

  final SocialRepository _social;
  final String userId;

  RiderProfile? _rider;
  bool _loading = true;
  bool _notFound = false;
  String? _error;

  RiderProfile? get rider => _rider;
  bool get loading => _loading;
  bool get notFound => _notFound;
  String? get error => _error;

  /// The signed-in rider's own profile: no Follow button.
  bool get isMe => _social.userId == userId;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _rider = await _social.rider(userId);
      _notFound = _rider == null;
    } on SocialException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Follows or unfollows at once; puts it back if the server refuses.
  /// Returns why it failed, or null.
  Future<String?> toggleFollow() async {
    final before = _rider;
    if (before == null || isMe) return null;
    final follow = !before.followedByMe;
    _rider = before.copyWith(
      followedByMe: follow,
      followerCount: before.followerCount + (follow ? 1 : -1),
    );
    notifyListeners();
    try {
      follow ? await _social.follow(userId) : await _social.unfollow(userId);
      return null;
    } on SocialException catch (e) {
      // Only undo if nothing changed it since (another tap).
      if (_rider?.followedByMe == follow) {
        _rider = before;
        notifyListeners();
      }
      return e.message;
    }
  }
}
