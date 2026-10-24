import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';
import '../models/json.dart';
import '../models/profile.dart';
import '../models/report.dart';

/// Why reporting, blocking or moderating failed, safe to show riders.
class ModerationException implements Exception {
  const ModerationException(this.message);

  final String message;

  static const failed = ModerationException(
    "Couldn't reach Pasyar. Check your connection and try again.",
  );
  static const notAdmin = ModerationException(
    'Only Pasyar moderators can do that.',
  );

  @override
  String toString() => 'ModerationException: $message';
}

/// What an admin does with reported content.
enum ModerationAction {
  /// Hide it from everyone but its author; closes its reports.
  hide,

  /// Show it again (reports stay closed).
  unhide,

  /// Keep it; closes its reports.
  dismiss,
}

/// One reported loop, post, comment or rider in the admin queue, with all
/// its open reports.
class ReportedItem {
  const ReportedItem({
    required this.targetType,
    required this.targetId,
    required this.reportCount,
    required this.reasons,
    required this.lastReportedAt,
    required this.isHidden,
    this.preview,
    this.authorId,
    this.authorName,
  });

  final ReportTarget targetType;
  final String targetId;
  final int reportCount;

  /// Newest first.
  final List<String> reasons;
  final DateTime lastReportedAt;
  final bool isHidden;

  /// Caption, comment, loop or rider name; null when it was deleted.
  final String? preview;
  final String? authorId;
  final String? authorName;

  factory ReportedItem.fromJson(Json json) => ReportedItem(
    targetType: ReportTarget.fromValue(json['target_type'] as String),
    targetId: json['target_id'] as String,
    reportCount: toIntOrNull(json['report_count']) ?? 0,
    reasons: [for (final r in json['reasons'] as List? ?? const []) '$r'],
    lastReportedAt: parseTimestamp(json['last_reported_at']),
    isHidden: json['is_hidden'] as bool? ?? false,
    preview: json['preview'] as String?,
    authorId: json['author_id'] as String?,
    authorName: json['author_name'] as String?,
  );

  ReportedItem copyWith({bool? isHidden}) => ReportedItem(
    targetType: targetType,
    targetId: targetId,
    reportCount: reportCount,
    reasons: reasons,
    lastReportedAt: lastReportedAt,
    isHidden: isHidden ?? this.isHidden,
    preview: preview,
    authorId: authorId,
    authorName: authorName,
  );
}

/// Reporting and blocking for riders; the report queue for admins.
abstract interface class ModerationRepository {
  /// Bumped when the rider blocks or unblocks someone, so feeds reload.
  ValueListenable<int> get blocksRevision;

  /// Reporting the same thing twice is fine. Throws [ModerationException].
  Future<void> report(ReportTarget target, String id, String reason);

  /// Throws [ModerationException].
  Future<void> block(String userId);
  Future<void> unblock(String userId);

  /// Riders the signed-in rider blocked, newest first. Throws
  /// [ModerationException].
  Future<List<ProfileSummary>> blocked();

  /// Throws [ModerationException].
  Future<bool> isBlocked(String userId);

  /// False on any error: the moderation screen just stays out of sight.
  Future<bool> isAdmin();

  /// Open reports, most reported first. Throws [ModerationException].
  Future<List<ReportedItem>> reportQueue();

  /// Throws [ModerationException].
  Future<void> moderate(ReportTarget target, String id, ModerationAction action);
}

class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository(this._client);

  final SupabaseClient _client;
  final _blocks = ValueNotifier(0);

  @override
  ValueListenable<int> get blocksRevision => _blocks;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw ModerationException.failed;
    return id;
  }

  Future<T> _guard<T>(String what, Future<T> Function() run) async {
    try {
      return await run();
    } on ModerationException {
      rethrow;
    } on PostgrestException catch (e) {
      debugPrint('moderation: $what failed: ${e.code} ${e.message}');
      if (e.code == '42501') throw ModerationException.notAdmin;
      throw ModerationException.failed;
    } on Exception catch (e) {
      debugPrint('moderation: $what failed: $e');
      throw ModerationException.failed;
    }
  }

  @override
  Future<void> report(ReportTarget target, String id, String reason) =>
      _guard('report', () async {
        try {
          await _client
              .from('reports')
              .insert(
                Report.insertJson(
                  targetType: target,
                  targetId: id,
                  reason: reason,
                ),
              );
        } on PostgrestException catch (e) {
          // Already reported: nothing more to do.
          if (e.code != '23505') rethrow;
        }
      });

  @override
  Future<void> block(String userId) => _guard('block', () async {
    await _client
        .from('blocks')
        .upsert({'blocked_id': userId}, ignoreDuplicates: true);
    _blocks.value++;
  });

  @override
  Future<void> unblock(String userId) => _guard('unblock', () async {
    await _client
        .from('blocks')
        .delete()
        .eq('blocker_id', _uid)
        .eq('blocked_id', userId);
    _blocks.value++;
  });

  @override
  Future<List<ProfileSummary>> blocked() => _guard('blocked', () async {
    final rows = await _client
        .from('blocks')
        .select('created_at, profiles!blocks_blocked_id_fkey(id,display_name,avatar_url)')
        .eq('blocker_id', _uid)
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        if (r['profiles'] case final Json p) ProfileSummary.fromJson(p),
    ];
  });

  @override
  Future<bool> isBlocked(String userId) => _guard('isBlocked', () async {
    final row = await _client
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', _uid)
        .eq('blocked_id', userId)
        .maybeSingle();
    return row != null;
  });

  @override
  Future<bool> isAdmin() async {
    try {
      return await _client.rpc<bool>('is_admin');
    } on Exception catch (e) {
      debugPrint('moderation: is_admin failed: $e');
      return false;
    }
  }

  @override
  Future<List<ReportedItem>> reportQueue() => _guard('queue', () async {
    final rows = await _client.rpc<List<dynamic>>('admin_report_queue');
    return [for (final r in rows) ReportedItem.fromJson(r as Json)];
  });

  @override
  Future<void> moderate(
    ReportTarget target,
    String id,
    ModerationAction action,
  ) => _guard(
    'moderate',
    () => _client.rpc<void>(
      'admin_moderate',
      params: {
        'p_target_type': target.value,
        'p_target_id': id,
        'p_action': action.name,
      },
    ),
  );
}
