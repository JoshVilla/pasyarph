import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club.dart';
import '../models/json.dart';

/// Why a club action failed. [message] is safe to show riders.
class ClubException implements Exception {
  const ClubException(this.code, this.message);

  final String code;
  final String message;

  static const offline = ClubException(
    'offline',
    "Couldn't reach Pasyar. Check your connection and try again.",
  );
  static const inviteNotFound = ClubException(
    'invite_not_found',
    "That invite link doesn't work anymore. Ask the club's owner for a new "
        'one.',
  );

  @override
  String toString() => 'ClubException($code)';
}

/// Riding clubs: create, invite with a link, join, leave (Prompt 17).
abstract interface class ClubRepository {
  /// The signed-in rider.
  String? get userId;

  /// Bumped after a club is created, joined, left or deleted, so lists of
  /// clubs can reload.
  ValueListenable<int> get revision;

  /// The rider's clubs by name, with their role and member counts.
  Future<List<Club>> mine();

  /// One club with the rider's role (null if not a member).
  Future<Club?> club(String id);

  /// Members, owner first. Only members can list them.
  Future<List<ClubMember>> members(String clubId);

  /// Creates a club owned by the rider. A [photoJpeg] that fails to upload
  /// is skipped (the club is still made).
  Future<Club> create(String name, {Uint8List? photoJpeg});

  /// The invite code; owner only.
  Future<String> inviteCode(String clubId);

  /// A new invite code, so old links stop working; owner only.
  Future<String> resetInvite(String clubId);

  /// The club an invite code is for, or null for an unknown code.
  Future<Club?> byInvite(String code);

  /// Joins with an invite code; returns the club's id. Throws
  /// [ClubException.inviteNotFound].
  Future<String> join(String code);

  /// Members leave; owners delete the club instead.
  Future<void> leave(String clubId);

  /// Owner only. The club's loops become private to their owners.
  Future<void> delete(String clubId);
}

class SupabaseClubRepository implements ClubRepository {
  SupabaseClubRepository(this._client);

  final SupabaseClient _client;
  final _revision = ValueNotifier(0);

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  ValueListenable<int> get revision => _revision;

  String get _uid {
    final id = userId;
    if (id == null) throw ClubException.offline;
    return id;
  }

  Future<T> _guard<T>(String what, Future<T> Function() run) async {
    try {
      return await run();
    } on ClubException {
      rethrow;
    } on PostgrestException catch (e) {
      debugPrint('clubs: $what failed: ${e.code} ${e.message}');
      if (e.message.contains('invite_not_found')) {
        throw ClubException.inviteNotFound;
      }
      throw ClubException.offline;
    } on Exception catch (e) {
      debugPrint('clubs: $what failed: $e');
      throw ClubException.offline;
    }
  }

  List<Club> _clubs(List<dynamic> rows) => [
    for (final r in rows) Club.fromJson(r as Json),
  ];

  @override
  Future<List<Club>> mine() => _guard(
    'my_clubs',
    () async => _clubs(await _client.rpc<List<dynamic>>('my_clubs')),
  );

  @override
  Future<Club?> club(String id) => _guard('club_info', () async {
    final rows = await _client.rpc<List<dynamic>>(
      'club_info',
      params: {'p_club_id': id},
    );
    return _clubs(rows).firstOrNull;
  });

  @override
  Future<List<ClubMember>> members(String clubId) =>
      _guard('members', () async {
        final rows = await _client
            .from('club_members')
            .select(ClubMember.columns)
            .eq('club_id', clubId)
            .order('role')
            .order('created_at')
            .limit(500);
        return [for (final r in rows) ClubMember.fromJson(r)];
      });

  @override
  Future<Club> create(String name, {Uint8List? photoJpeg}) =>
      _guard('create', () async {
        final uid = _uid;
        final row = await _client
            .from('clubs')
            .insert({'name': name.trim()})
            .select(Club.columns)
            .single();
        var club = Club.fromJson(row);
        if (photoJpeg != null) {
          try {
            final url = await _uploadPhoto(uid, club.id, photoJpeg);
            await _client
                .from('clubs')
                .update({'photo_url': url})
                .eq('id', club.id);
            club = Club.fromJson({...row, 'photo_url': url});
          } on Exception catch (e) {
            debugPrint('clubs: photo upload failed: $e');
          }
        }
        _revision.value++;
        return club;
      });

  /// Into the owner's avatars folder (the only place they can write).
  Future<String> _uploadPhoto(String uid, String clubId, Uint8List jpeg) async {
    final path = '$uid/club-$clubId.jpg';
    final bucket = _client.storage.from('avatars');
    await bucket.uploadBinary(
      path,
      jpeg,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'image/jpeg',
        cacheControl: '3600',
      ),
    );
    final version = DateTime.now().millisecondsSinceEpoch;
    return '${bucket.getPublicUrl(path)}?v=$version';
  }

  Future<String> _code(String fn, String clubId) => _guard(fn, () async {
    final code = await _client.rpc<String?>(fn, params: {'p_club_id': clubId});
    if (code == null) throw ClubException.offline;
    return code;
  });

  @override
  Future<String> inviteCode(String clubId) => _code('club_invite_code', clubId);

  @override
  Future<String> resetInvite(String clubId) =>
      _code('reset_club_invite', clubId);

  @override
  Future<Club?> byInvite(String code) => _guard('club_by_invite', () async {
    final rows = await _client.rpc<List<dynamic>>(
      'club_by_invite',
      params: {'p_code': code},
    );
    return _clubs(rows).firstOrNull;
  });

  @override
  Future<String> join(String code) => _guard('join', () async {
    final id = await _client.rpc<String>('join_club', params: {'p_code': code});
    _revision.value++;
    return id;
  });

  @override
  Future<void> leave(String clubId) => _guard('leave', () async {
    await _client
        .from('club_members')
        .delete()
        .eq('club_id', clubId)
        .eq('user_id', _uid);
    _revision.value++;
  });

  @override
  Future<void> delete(String clubId) => _guard('delete', () async {
    await _client.from('clubs').delete().eq('id', clubId).eq('owner_id', _uid);
    _revision.value++;
  });
}
