import 'package:flutter/foundation.dart';

import '../../../core/links.dart';
import '../../../data/models/club.dart';
import '../../../data/repositories/club_repository.dart';

/// A club's page: the club, its members (members only), and the owner's
/// invite link. Actions return why they failed, or null.
class ClubController extends ChangeNotifier {
  ClubController({required ClubRepository clubs, required this.clubId})
    : _clubs = clubs;

  final ClubRepository _clubs;
  final String clubId;

  Club? _club;
  List<ClubMember>? _members;
  bool _loading = true;
  bool _busy = false;
  bool _notFound = false;
  String? _error;

  Club? get club => _club;

  /// Null until loaded, and for non-members.
  List<ClubMember>? get members => _members;
  bool get loading => _loading;

  /// Leaving, deleting or getting the invite link.
  bool get busy => _busy;

  /// No such club (or it was deleted).
  bool get notFound => _notFound;
  String? get error => _error;
  String? get myId => _clubs.userId;

  Future<void> load() async {
    _error = null;
    notifyListeners();
    try {
      final club = await _clubs.club(clubId);
      _club = club;
      _notFound = club == null;
      _members = club != null && club.isMember
          ? await _clubs.members(clubId)
          : null;
    } on ClubException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String?> _run(Future<void> Function() action) async {
    if (_busy) return null;
    _busy = true;
    notifyListeners();
    try {
      await action();
      return null;
    } on ClubException catch (e) {
      return e.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// The link to share; owner only. Throws [ClubException].
  Future<Uri> inviteLink() async {
    late String code;
    final error = await _run(
      () async => code = await _clubs.inviteCode(clubId),
    );
    if (error != null) throw ClubException('invite', error);
    return AppLinks.clubInvite(code);
  }

  /// A new link; the old one stops working. Throws [ClubException].
  Future<Uri> resetInviteLink() async {
    late String code;
    final error = await _run(
      () async => code = await _clubs.resetInvite(clubId),
    );
    if (error != null) throw ClubException('invite', error);
    return AppLinks.clubInvite(code);
  }

  Future<String?> leave() => _run(() => _clubs.leave(clubId));

  Future<String?> delete() => _run(() => _clubs.delete(clubId));
}
