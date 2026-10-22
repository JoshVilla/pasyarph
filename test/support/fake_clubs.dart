import 'package:flutter/foundation.dart';
import 'package:pasyarph/data/models/club.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/models/profile.dart';
import 'package:pasyarph/data/repositories/club_repository.dart';

/// In-memory clubs for [userId], with invite codes and switchable failures.
class FakeClubRepository implements ClubRepository {
  FakeClubRepository({this.userId = 'me'});

  @override
  final String? userId;

  final clubs = <String, Club>{};
  final roster = <String, List<ClubMember>>{};
  final codes = <String, String>{};
  final calls = <String>[];
  final _revision = ValueNotifier(0);
  var _next = 0;

  /// Next call throws this.
  ClubException? failNext;

  void _maybeFail() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  /// Adds a club; [memberIds] beyond the owner join as members.
  Club add(
    String id,
    String name, {
    String ownerId = 'me',
    List<String> memberIds = const [],
    String? code,
  }) {
    final club = Club(
      id: id,
      name: name,
      ownerId: ownerId,
      createdAt: DateTime.utc(2026, 10, 1),
    );
    clubs[id] = club;
    codes[id] = code ?? (codes.length + 1).toRadixString(16).padLeft(16, '0');
    roster[id] = [
      _member(id, ownerId, ClubRole.owner),
      for (final m in memberIds) _member(id, m, ClubRole.member),
    ];
    return club;
  }

  ClubMember _member(String clubId, String uid, ClubRole role) => ClubMember(
    clubId: clubId,
    userId: uid,
    role: role,
    createdAt: DateTime.utc(2026, 10, 1),
    profile: ProfileSummary(id: uid, displayName: _names[uid] ?? 'Rider $uid'),
  );

  static const _names = {
    'me': 'Mark Estrada',
    'ana': 'Ana Lopez',
    'jun': 'Jun Mendoza',
    'rico': 'Rico Navarro',
  };

  /// As `club_info` sees it for [userId].
  Club _info(String id) {
    final c = clubs[id]!;
    final list = roster[id]!;
    final mine = list.where((m) => m.userId == userId).firstOrNull;
    return Club(
      id: c.id,
      name: c.name,
      ownerId: c.ownerId,
      photoUrl: c.photoUrl,
      createdAt: c.createdAt,
      myRole: mine?.role,
      memberCount: list.length,
    );
  }

  @override
  ValueListenable<int> get revision => _revision;

  @override
  Future<List<Club>> mine() async {
    calls.add('mine');
    _maybeFail();
    return [
      for (final id in clubs.keys)
        if (roster[id]!.any((m) => m.userId == userId)) _info(id),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<Club?> club(String id) async {
    calls.add('club:$id');
    _maybeFail();
    return clubs.containsKey(id) ? _info(id) : null;
  }

  @override
  Future<List<ClubMember>> members(String clubId) async {
    calls.add('members:$clubId');
    _maybeFail();
    return List.of(roster[clubId] ?? const []);
  }

  @override
  Future<Club> create(String name, {Uint8List? photoJpeg}) async {
    calls.add('create:${name.trim()}');
    _maybeFail();
    final club = add('new${_next++}', name.trim(), ownerId: userId!);
    _revision.value++;
    return _info(club.id);
  }

  @override
  Future<String> inviteCode(String clubId) async {
    calls.add('invite:$clubId');
    _maybeFail();
    return codes[clubId]!;
  }

  @override
  Future<String> resetInvite(String clubId) async {
    calls.add('reset:$clubId');
    _maybeFail();
    return codes[clubId] = 'feedface${_next++}'.padRight(16, '0');
  }

  String? _byCode(String code) =>
      codes.entries.where((e) => e.value == code).firstOrNull?.key;

  @override
  Future<Club?> byInvite(String code) async {
    calls.add('byInvite:$code');
    _maybeFail();
    final id = _byCode(code);
    return id == null ? null : _info(id);
  }

  @override
  Future<String> join(String code) async {
    calls.add('join:$code');
    _maybeFail();
    final id = _byCode(code);
    if (id == null) throw ClubException.inviteNotFound;
    final list = roster[id]!;
    if (!list.any((m) => m.userId == userId)) {
      list.add(_member(id, userId!, ClubRole.member));
    }
    _revision.value++;
    return id;
  }

  @override
  Future<void> leave(String clubId) async {
    calls.add('leave:$clubId');
    _maybeFail();
    roster[clubId]?.removeWhere(
      (m) => m.userId == userId && m.role == ClubRole.member,
    );
    _revision.value++;
  }

  @override
  Future<void> delete(String clubId) async {
    calls.add('delete:$clubId');
    _maybeFail();
    clubs.remove(clubId);
    roster.remove(clubId);
    codes.remove(clubId);
    _revision.value++;
  }
}
