import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/data/ids.dart';
import 'package:pasyarph/data/repositories/ride_history_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class _Uploader implements RideUploader {
  final uploaded = <String>[];
  bool fail = false;

  @override
  Future<void> upload(RideSummary ride) async {
    if (fail) throw Exception('offline');
    uploaded.add(ride.id);
  }
}

final _route = [
  for (var i = 0; i <= 400; i++) LatLng(16.672 + i * 0.0001, 121.457),
];

RideSummary _ride({double ridden = 40000, DateTime? ended, String? id}) =>
    RideSummary(
      id: id ?? newId(),
      startedAt: DateTime(2026, 10, 18, 8),
      endedAt: ended ?? DateTime(2026, 10, 18, 11),
      riddenM: ridden,
      loopM: 50000,
      loopDurationS: 3 * 3600,
      curvinessScore: 210,
      stop: const RideStop(
        location: LatLng(16.7, 121.46),
        type: 'waterfall',
        name: 'Talon',
      ),
      reachedStop: true,
      route: _route,
      preview: RideSummary.previewOf(_route),
    );

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('ids are v4 UUIDs', () {
    final a = newId();
    expect(isId(a), isTrue);
    expect(a[14], '4');
    expect(newId(), isNot(a));
  });

  test('preview keeps at most 120 points, ends included', () {
    final p = RideSummary.previewOf(_route);
    expect(p, hasLength(RideSummary.previewPoints));
    expect(p.first, _route.first);
    expect(p.last, _route.last);
    expect(RideSummary.previewOf(_route.take(10).toList()), hasLength(10));
  });

  test('who can post: recent, unposted, ridden a quarter of the loop', () {
    final now = DateTime(2026, 10, 19, 9);
    expect(_ride().canPost(now), isTrue);
    expect(_ride(ridden: 12000).canPost(now), isFalse);
    expect(_ride().copyWith(posted: true).canPost(now), isFalse);
    expect(_ride().canPost(DateTime(2026, 10, 25, 12)), isFalse);
    expect(_ride(id: '').canPost(now), isFalse);
  });

  test('row JSON: UTC times, EWKT route, stop as jsonb', () {
    final row = _ride().toRowJson();
    expect(row['started_at'], endsWith('Z'));
    expect(row['route'], startsWith('SRID=4326;LINESTRING('));
    expect(row['ridden_m'], 40000);
    expect((row['main_stop'] as Map)['name'], 'Talon');
  });

  test(
    'save uploads, then drops the full route but keeps the preview',
    () async {
      final up = _Uploader();
      final repo = LocalRideHistoryRepository(uploader: up);
      final ride = _ride();
      await repo.save(ride);
      expect(up.uploaded, [ride.id]);
      final kept = (await repo.byId(ride.id))!;
      expect(kept.synced, isTrue);
      expect(kept.route, isNull);
      expect(kept.preview, hasLength(RideSummary.previewPoints));
      expect(kept.stop!.name, 'Talon');
      expect(kept.loopDurationS, 3 * 3600);
    },
  );

  test('offline: kept with its route, uploaded on the next sync', () async {
    final up = _Uploader()..fail = true;
    final repo = LocalRideHistoryRepository(uploader: up);
    final ride = _ride();
    await repo.save(ride);
    expect((await repo.byId(ride.id))!.synced, isFalse);
    expect((await repo.byId(ride.id))!.route, hasLength(_route.length));
    expect(await repo.sync(), isFalse);

    up.fail = false;
    expect(await repo.sync(), isTrue);
    expect(up.uploaded, [ride.id]);
    expect((await repo.byId(ride.id))!.synced, isTrue);
  });

  test('newest first; markPosted sticks', () async {
    final repo = LocalRideHistoryRepository();
    final older = _ride(ended: DateTime(2026, 10, 17, 11));
    final newer = _ride();
    await repo.save(older);
    await repo.save(newer);
    expect([for (final r in await repo.all()) r.id], [newer.id, older.id]);
    await repo.markPosted(older.id);
    expect((await repo.byId(older.id))!.posted, isTrue);
    expect((await repo.byId(newer.id))!.posted, isFalse);
  });

  test('rides saved before syncing existed load as not postable', () async {
    await SharedPreferencesAsync().setString(
      'ride_history',
      jsonEncode([
        {
          'started_at': '2026-10-18T08:00:00.000',
          'ended_at': '2026-10-18T09:00:00.000',
          'ridden_m': 30000,
          'loop_m': 50000,
          'stop_name': 'Talon',
          'reached_stop': true,
        },
      ]),
    );
    final up = _Uploader();
    final repo = LocalRideHistoryRepository(uploader: up);
    final old = (await repo.all()).single;
    expect(old.synced, isTrue);
    expect(old.canPost(DateTime(2026, 10, 18, 10)), isFalse);
    expect(await repo.sync(), isTrue);
    expect(up.uploaded, isEmpty);
  });
}
