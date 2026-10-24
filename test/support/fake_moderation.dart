import 'package:flutter/foundation.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/models/profile.dart';
import 'package:pasyarph/data/repositories/moderation_repository.dart';

/// In-memory reports, blocks and an admin queue.
class FakeModerationRepository implements ModerationRepository {
  FakeModerationRepository({
    this.admin = false,
    List<ReportedItem>? queue,
    Map<String, String>? names,
  }) : queue = queue ?? [],
       names = names ?? {};

  bool admin;
  final List<ReportedItem> queue;

  /// Display names for blocked riders, by id.
  final Map<String, String> names;
  final reports = <(ReportTarget, String, String)>[];
  final blockedIds = <String>[];
  final moderated = <(ReportTarget, String, ModerationAction)>[];
  bool fail = false;
  final _blocks = ValueNotifier(0);

  @override
  ValueListenable<int> get blocksRevision => _blocks;

  void _check() {
    if (fail) throw ModerationException.failed;
  }

  @override
  Future<void> report(ReportTarget target, String id, String reason) async {
    _check();
    reports.add((target, id, reason));
  }

  @override
  Future<void> block(String userId) async {
    _check();
    if (!blockedIds.contains(userId)) blockedIds.add(userId);
    _blocks.value++;
  }

  @override
  Future<void> unblock(String userId) async {
    _check();
    blockedIds.remove(userId);
    _blocks.value++;
  }

  @override
  Future<List<ProfileSummary>> blocked() async {
    _check();
    return [
      for (final id in blockedIds.reversed)
        ProfileSummary(id: id, displayName: names[id]),
    ];
  }

  @override
  Future<bool> isBlocked(String userId) async => blockedIds.contains(userId);

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<List<ReportedItem>> reportQueue() async {
    _check();
    if (!admin) throw ModerationException.notAdmin;
    return List.of(queue);
  }

  @override
  Future<void> moderate(
    ReportTarget target,
    String id,
    ModerationAction action,
  ) async {
    _check();
    if (!admin) throw ModerationException.notAdmin;
    moderated.add((target, id, action));
  }
}
