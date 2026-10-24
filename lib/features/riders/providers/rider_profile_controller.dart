import 'package:flutter/foundation.dart';

import '../../../data/models/profile.dart';
import '../../../data/repositories/moderation_repository.dart';
import '../../../data/repositories/social_repository.dart';

/// Another rider's profile, the Follow button, and blocking.
class RiderProfileController extends ChangeNotifier {
  RiderProfileController({
    required SocialRepository social,
    required this.userId,
    ModerationRepository? moderation,
  }) : _social = social,
       _moderation = moderation;

  final SocialRepository _social;
  final ModerationRepository? _moderation;
  final String userId;

  RiderProfile? _rider;
  bool _loading = true;
  bool _notFound = false;
  bool _blocked = false;
  String? _error;

  RiderProfile? get rider => _rider;
  bool get loading => _loading;
  bool get notFound => _notFound;
  String? get error => _error;

  /// The signed-in rider blocked them: their rides are hidden, no Follow.
  bool get blocked => _blocked;

  /// The signed-in rider's own profile: no Follow button.
  bool get isMe => _social.userId == userId;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      _rider = await _social.rider(userId);
      _notFound = _rider == null;
      final moderation = _moderation;
      if (moderation != null && !isMe && !_notFound) {
        _blocked = await moderation.isBlocked(userId);
      }
    } on SocialException catch (e) {
      _error = e.message;
    } on ModerationException catch (e) {
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
    if (before == null || isMe || _blocked) return null;
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

  /// After blocking them (⋯ → Block): reload, since blocking unfollows.
  Future<void> markBlocked() async {
    _blocked = true;
    await load();
  }

  /// Unblocks them and reloads. Returns why it failed, or null.
  Future<String?> unblock() async {
    final moderation = _moderation;
    if (moderation == null) return null;
    try {
      await moderation.unblock(userId);
    } on ModerationException catch (e) {
      return e.message;
    }
    _blocked = false;
    await load();
    return null;
  }
}
