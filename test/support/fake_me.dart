import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pasyarph/core/settings/app_settings.dart';
import 'package:pasyarph/data/models/loop.dart';
import 'package:pasyarph/data/repositories/me_repository.dart';

/// In-memory totals and saved loops. [loops] are the loops that can be
/// saved, by id.
class FakeMeRepository implements MeRepository {
  FakeMeRepository({
    this.serverTotals = RiderTotals.zero,
    Map<String, Loop>? loops,
  }) : loops = loops ?? {};

  RiderTotals serverTotals;
  final Map<String, Loop> loops;
  final saved = <String>[];
  final calls = <String>[];
  bool fail = false;
  bool deleted = false;

  /// Holds deleteAccount() until it completes.
  Completer<void>? deleteGate;
  final _revision = ValueNotifier(0);

  @override
  ValueListenable<int> get savedRevision => _revision;

  @override
  Future<RiderTotals> totals() async {
    calls.add('totals');
    if (fail) throw MeException.loadFailed;
    return serverTotals;
  }

  @override
  Future<List<Loop>> savedLoops() async {
    if (fail) throw MeException.loadFailed;
    return [for (final id in saved.reversed) ?loops[id]];
  }

  @override
  Future<bool> isSaved(String loopId) async => saved.contains(loopId);

  @override
  Future<void> saveLoop(String loopId) async {
    calls.add('save:$loopId');
    if (fail) throw MeException.saveFailed;
    if (!saved.contains(loopId)) saved.add(loopId);
    _revision.value++;
  }

  @override
  Future<void> unsaveLoop(String loopId) async {
    calls.add('unsave:$loopId');
    if (fail) throw MeException.saveFailed;
    saved.remove(loopId);
    _revision.value++;
  }

  @override
  Future<void> deleteAccount() async {
    calls.add('delete');
    await deleteGate?.future;
    if (fail) throw MeException.deleteFailed;
    deleted = true;
  }
}

/// Settings kept in memory.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([Map<String, bool>? values]) : values = values ?? {};

  final Map<String, bool> values;
  final strings = <String, String>{};
  @override
  Future<String?> getString(String key) async => strings[key];
  @override
  Future<void> setString(String key, String value) async {
    strings[key] = value;
  }

  @override
  Future<bool?> getBool(String key) async => values[key];

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
}
