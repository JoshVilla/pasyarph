import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/club.dart';
import '../models/enums.dart';
import '../models/json.dart';
import '../models/loop.dart';

/// Why a loop couldn't be saved or loaded. [message] is safe to show riders.
class LoopException implements Exception {
  const LoopException(this.message);

  final String message;

  static const saveFailed = LoopException(
    "Couldn't save your loop. Check your connection and try again.",
  );
  static const loadFailed = LoopException(
    "Couldn't load your loops. Check your connection.",
  );

  @override
  String toString() => 'LoopException: $message';
}

/// Loops the rider makes in the Create tab, and the clubs they can share
/// them with.
abstract interface class LoopRepository {
  /// Bumped after every save, so lists of loops can reload.
  ValueListenable<int> get revision;

  /// Inserts a loop with an id picked on the phone. Throws [LoopException].
  Future<void> create(String id, NewLoop loop);

  /// Replaces an existing loop of the rider's. Throws [LoopException].
  Future<void> update(String id, NewLoop loop);

  /// Renames a loop of the rider's and changes who sees it ([clubId] only
  /// for [LoopVisibility.club]). Throws [LoopException].
  Future<void> editSharing(
    String id, {
    required String name,
    required LoopVisibility visibility,
    String? clubId,
  });

  /// Deletes a loop of the rider's, and the posts made with it. Throws
  /// [LoopException].
  Future<void> delete(String id);

  /// The signed-in rider's loops, newest first. Throws [LoopException].
  Future<List<Loop>> mine();

  /// Another rider's loops the signed-in rider can see (public, or a club
  /// they share), newest first. Throws [LoopException].
  Future<List<Loop>> ofRider(String userId);

  /// Clubs the signed-in rider belongs to, by name. Throws [LoopException].
  Future<List<Club>> myClubs();
}

class SupabaseLoopRepository implements LoopRepository {
  SupabaseLoopRepository(this._client);

  final SupabaseClient _client;
  final _revision = ValueNotifier(0);

  @override
  ValueListenable<int> get revision => _revision;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw LoopException.saveFailed;
    return id;
  }

  @override
  Future<void> create(String id, NewLoop loop) async {
    try {
      await _write(
        () => _client.from('loops').insert({'id': id, ...loop.toJson()}),
      );
    } on LoopException {
      if (loop.caption == null) rethrow;
      await _write(
        () => _client
            .from('loops')
            .insert({'id': id, ...loop.toJson(includeCaption: false)}),
      );
    }
  }

  @override
  Future<void> update(String id, NewLoop loop) async {
    // source can't change after insert (no update grant).
    final values = loop.toJson()..remove('source');
    try {
      await _write(
        () => _client
            .from('loops')
            .update(values)
            .eq('id', id)
            .eq('owner_id', _uid),
      );
    } on LoopException {
      if (loop.caption == null) rethrow;
      final fallback = loop.toJson(includeCaption: false)..remove('source');
      await _write(
        () => _client
            .from('loops')
            .update(fallback)
            .eq('id', id)
            .eq('owner_id', _uid),
      );
    }
  }

  @override
  Future<void> editSharing(
    String id, {
    required String name,
    required LoopVisibility visibility,
    String? clubId,
  }) => _write(
    () => _client
        .from('loops')
        .update({
          'name': name,
          'visibility': visibility.value,
          'club_id': visibility == LoopVisibility.club ? clubId : null,
        })
        .eq('id', id)
        .eq('owner_id', _uid),
  );

  @override
  Future<void> delete(String id) => _write(
    () => _client.from('loops').delete().eq('id', id).eq('owner_id', _uid),
  );

  Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } on Exception {
      throw LoopException.saveFailed;
    }
    _revision.value++;
  }

  @override
  Future<List<Loop>> mine() async {
    try {
      final rows = await _client
          .from('loops')
          .select(Loop.columns)
          .eq('owner_id', _uid)
          .order('created_at', ascending: false)
          .limit(50);
      return [for (final r in rows) Loop.fromJson(r)];
    } on LoopException {
      rethrow;
    } on Exception {
      // Backwards-compatible read for databases without the caption column.
      try {
        final rows = await _client
            .from('loops')
            .select(Loop.columnsWithoutCaption)
            .eq('owner_id', _uid)
            .order('created_at', ascending: false)
            .limit(50);
        return [for (final r in rows) Loop.fromJson(r)];
      } on Exception {
        throw LoopException.loadFailed;
      }
    }
  }

  @override
  Future<List<Loop>> ofRider(String userId) async {
    try {
      final rows = await _client
          .from('loops')
          .select(Loop.columns)
          .eq('owner_id', userId)
          // Private loops never show on a profile, not even your own.
          .neq('visibility', 'private')
          .order('created_at', ascending: false)
          .limit(50);
      return [for (final r in rows) Loop.fromJson(r)];
    } on Exception {
      try {
        final rows = await _client
            .from('loops')
            .select(Loop.columnsWithoutCaption)
            .eq('owner_id', userId)
            .neq('visibility', 'private')
            .order('created_at', ascending: false)
            .limit(50);
        return [for (final r in rows) Loop.fromJson(r)];
      } on Exception {
        throw LoopException.loadFailed;
      }
    }
  }

  @override
  Future<List<Club>> myClubs() async {
    try {
      final rows = await _client
          .from('club_members')
          .select('clubs(id,name,owner_id,created_at)')
          .eq('user_id', _uid);
      final clubs = [
        for (final r in rows)
          if (r['clubs'] case final Json c) Club.fromJson(c),
      ]..sort((a, b) => a.name.compareTo(b.name));
      return clubs;
    } on LoopException {
      rethrow;
    } on Exception {
      throw LoopException.loadFailed;
    }
  }
}
