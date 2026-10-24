import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/json.dart';
import '../models/loop.dart';

/// Why something on the Me tab failed, with a message safe to show riders.
class MeException implements Exception {
  const MeException(this.message);

  final String message;

  static const loadFailed = MeException(
    "Couldn't load this. Check your connection and pull to refresh.",
  );
  static const saveFailed = MeException(
    "Couldn't save that. Check your connection and try again.",
  );
  static const deleteFailed = MeException(
    "Couldn't delete your account. Check your connection and try again.",
  );

  @override
  String toString() => 'MeException: $message';
}

/// The profile header's numbers (`my_totals()`).
class RiderTotals {
  const RiderTotals({
    required this.riddenM,
    required this.loopsRidden,
    required this.posts,
  });

  static const zero = RiderTotals(riddenM: 0, loopsRidden: 0, posts: 0);

  /// Every ride's GPS distance.
  final int riddenM;

  /// Rides that covered at least a quarter of their loop.
  final int loopsRidden;
  final int posts;

  factory RiderTotals.fromJson(Json json) => RiderTotals(
    riddenM: toIntOrNull(json['ridden_m']) ?? 0,
    loopsRidden: toIntOrNull(json['loops_ridden']) ?? 0,
    posts: toIntOrNull(json['posts']) ?? 0,
  );

  RiderTotals plus({int riddenM = 0, int loopsRidden = 0}) => RiderTotals(
    riddenM: this.riddenM + riddenM,
    loopsRidden: this.loopsRidden + loopsRidden,
    posts: posts,
  );

  @override
  bool operator ==(Object other) =>
      other is RiderTotals &&
      other.riddenM == riddenM &&
      other.loopsRidden == loopsRidden &&
      other.posts == posts;

  @override
  int get hashCode => Object.hash(riddenM, loopsRidden, posts);

  @override
  String toString() => 'RiderTotals($riddenM m, $loopsRidden loops, $posts)';
}

/// The signed-in rider's own things: totals, saved loops, and deleting the
/// account.
abstract interface class MeRepository {
  /// Bumped when a loop is saved or unsaved.
  ValueListenable<int> get savedRevision;

  /// Throws [MeException.loadFailed].
  Future<RiderTotals> totals();

  /// Newest saved first; loops the rider can no longer see are left out.
  /// Throws [MeException.loadFailed].
  Future<List<Loop>> savedLoops();

  /// Throws [MeException.loadFailed].
  Future<bool> isSaved(String loopId);

  /// Saving twice (or unsaving twice) is fine. Throws
  /// [MeException.saveFailed].
  Future<void> saveLoop(String loopId);
  Future<void> unsaveLoop(String loopId);

  /// Deletes the account, all its data and its photos (delete-account Edge
  /// Function). Throws [MeException.deleteFailed].
  Future<void> deleteAccount();
}

class SupabaseMeRepository implements MeRepository {
  SupabaseMeRepository(this._client);

  final SupabaseClient _client;
  final _savedRevision = ValueNotifier(0);

  @override
  ValueListenable<int> get savedRevision => _savedRevision;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw MeException.loadFailed;
    return id;
  }

  @override
  Future<RiderTotals> totals() async {
    try {
      final rows = await _client.rpc<List<dynamic>>('my_totals');
      return rows.isEmpty
          ? RiderTotals.zero
          : RiderTotals.fromJson(rows.first as Json);
    } on Exception catch (e) {
      debugPrint('me: my_totals failed: $e');
      throw MeException.loadFailed;
    }
  }

  @override
  Future<List<Loop>> savedLoops() async {
    try {
      final rows = await _client
          .from('saved_loops')
          .select('created_at, loops(${Loop.columns})')
          .eq('user_id', _uid)
          .order('created_at', ascending: false)
          .limit(100);
      return [
        for (final r in rows)
          if (r['loops'] case final Json l) Loop.fromJson(l),
      ];
    } on MeException {
      rethrow;
    } on Exception catch (e) {
      debugPrint('me: saved loops failed: $e');
      throw MeException.loadFailed;
    }
  }

  @override
  Future<bool> isSaved(String loopId) async {
    try {
      final row = await _client
          .from('saved_loops')
          .select('loop_id')
          .eq('user_id', _uid)
          .eq('loop_id', loopId)
          .maybeSingle();
      return row != null;
    } on MeException {
      rethrow;
    } on Exception {
      throw MeException.loadFailed;
    }
  }

  @override
  Future<void> saveLoop(String loopId) => _write(
    () => _client.from('saved_loops').upsert({
      'loop_id': loopId,
    }, ignoreDuplicates: true),
  );

  @override
  Future<void> unsaveLoop(String loopId) => _write(
    () => _client
        .from('saved_loops')
        .delete()
        .eq('user_id', _uid)
        .eq('loop_id', loopId),
  );

  Future<void> _write(Future<void> Function() write) async {
    try {
      await write();
    } on Exception catch (e) {
      debugPrint('me: saved loop write failed: $e');
      throw MeException.saveFailed;
    }
    _savedRevision.value++;
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account');
    } on Exception catch (e) {
      debugPrint('me: delete-account failed: $e');
      throw MeException.deleteFailed;
    }
  }
}
