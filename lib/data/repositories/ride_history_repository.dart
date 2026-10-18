import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../geo/geo_codec.dart';
import '../ids.dart';
import '../models/json.dart';

/// The loop's main stop, as it was when the ride started.
class RideStop {
  const RideStop({required this.location, required this.type, this.name});

  final LatLng location;

  /// viewpoint, waterfall, attraction, food, or turnaround.
  final String type;
  final String? name;

  factory RideStop.fromJson(Json json) => RideStop(
    location: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    type: json['type'] as String? ?? 'turnaround',
    name: json['name'] as String?,
  );

  Json toJson() => {
    'name': name,
    'type': type,
    'lat': location.latitude,
    'lng': location.longitude,
  };
}

/// One finished ride. Kept on the phone and synced to the `rides` table; a
/// post must come from one (see [canPost]).
class RideSummary {
  const RideSummary({
    required this.startedAt,
    required this.endedAt,
    required this.riddenM,
    required this.loopM,
    required this.reachedStop,
    this.id = '',
    this.loopDurationS = 0,
    this.curvinessScore,
    this.stop,
    this.route,
    this.preview = const [],
    this.synced = false,
    this.posted = false,
  });

  /// UUID picked on the phone; empty for rides saved before syncing existed
  /// (those never sync and can't be posted).
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Distance actually ridden (GPS track).
  final double riddenM;

  /// Planned loop length and ride time.
  final int loopM;
  final int loopDurationS;
  final double? curvinessScore;
  final RideStop? stop;
  final bool reachedStop;

  /// The full planned loop; only kept until the ride is synced.
  final List<LatLng>? route;

  /// A light copy of the loop for thumbnails (at most [previewPoints]).
  final List<LatLng> preview;

  final bool synced;
  final bool posted;

  static const previewPoints = 120;

  /// Posting window and minimum share ridden, as enforced by
  /// create_post_from_ride.
  static const postWindow = Duration(days: 7);
  static const minRiddenShare = 0.25;

  Duration get duration => endedAt.difference(startedAt);
  String? get stopName => stop?.name;

  bool get longEnough => riddenM >= loopM * minRiddenShare;

  bool isExpired(DateTime now) => now.difference(endedAt) > postWindow;

  /// Can still be posted: not posted, recent, and ridden far enough.
  bool canPost(DateTime now) =>
      isId(id) && !posted && longEnough && !isExpired(now);

  RideSummary copyWith({bool? synced, bool? posted, bool dropRoute = false}) =>
      RideSummary(
        id: id,
        startedAt: startedAt,
        endedAt: endedAt,
        riddenM: riddenM,
        loopM: loopM,
        loopDurationS: loopDurationS,
        curvinessScore: curvinessScore,
        stop: stop,
        reachedStop: reachedStop,
        route: dropRoute ? null : route,
        preview: preview,
        synced: synced ?? this.synced,
        posted: posted ?? this.posted,
      );

  /// Every nth point of [route] so at most [previewPoints] remain, ends
  /// kept.
  static List<LatLng> previewOf(List<LatLng> route) {
    if (route.length <= previewPoints) return List.of(route);
    final step = (route.length - 1) / (previewPoints - 1);
    return [for (var i = 0; i < previewPoints; i++) route[(i * step).round()]];
  }

  factory RideSummary.fromJson(Json json) {
    final id = json['id'] as String? ?? '';
    List<LatLng>? points(Object? raw) => raw == null
        ? null
        : [
            for (final p in raw as List)
              LatLng(
                ((p as List)[1] as num).toDouble(),
                (p[0] as num).toDouble(),
              ),
          ];
    return RideSummary(
      id: id,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: DateTime.parse(json['ended_at'] as String),
      riddenM: (json['ridden_m'] as num).toDouble(),
      loopM: (json['loop_m'] as num).toInt(),
      loopDurationS: toIntOrNull(json['loop_duration_s']) ?? 0,
      curvinessScore: (json['curviness_score'] as num?)?.toDouble(),
      stop: switch (json['stop']) {
        final Json s => RideStop.fromJson(s),
        _ => null,
      },
      reachedStop: json['reached_stop'] as bool? ?? false,
      route: points(json['route']),
      preview: points(json['preview']) ?? const [],
      // Old rides without an id have nothing to sync.
      synced: json['synced'] as bool? ?? !isId(id),
      posted: json['posted'] as bool? ?? false,
    );
  }

  Json toJson() {
    List<List<double>> pts(List<LatLng> l) => [
      for (final p in l) [p.longitude, p.latitude],
    ];
    return {
      'id': id,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt.toIso8601String(),
      'ridden_m': riddenM,
      'loop_m': loopM,
      'loop_duration_s': loopDurationS,
      'curviness_score': curvinessScore,
      'stop': stop?.toJson(),
      'reached_stop': reachedStop,
      if (route != null) 'route': pts(route!),
      'preview': pts(preview),
      'synced': synced,
      'posted': posted,
    };
  }

  /// Insert payload for the `rides` table.
  Json toRowJson() => {
    'id': id,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    'ridden_m': riddenM.round(),
    'route': GeoCodec.lineStringToEwkt(route!),
    'loop_distance_m': loopM,
    'loop_duration_s': loopDurationS,
    'curviness_score': curvinessScore,
    'main_stop': stop?.toJson(),
    'reached_stop': reachedStop,
  };
}

abstract interface class RideHistoryRepository {
  /// Bumps whenever rides change (saved, synced, posted), so lists that stay
  /// alive (the Me tab) can reload.
  ValueListenable<int> get revision;

  /// Saves on the phone, then tries to upload (see [sync]).
  Future<void> save(RideSummary ride);

  /// Newest first.
  Future<List<RideSummary>> all();
  Future<RideSummary?> byId(String id);

  /// Uploads rides saved while offline. True when nothing is left.
  Future<bool> sync();

  Future<void> markPosted(String id);
}

/// Uploads one ride to Supabase. Throws on failure.
abstract interface class RideUploader {
  Future<void> upload(RideSummary ride);
}

class SupabaseRideUploader implements RideUploader {
  SupabaseRideUploader(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upload(RideSummary ride) async {
    try {
      await _client.from('rides').insert(ride.toRowJson());
    } on PostgrestException catch (e) {
      // Already there: an earlier upload went through but its reply didn't.
      if (e.code != '23505') rethrow;
    }
  }
}

/// Rides kept in shared preferences, synced through [uploader] (none in
/// tests and when signed out).
class LocalRideHistoryRepository implements RideHistoryRepository {
  LocalRideHistoryRepository({this.uploader});

  final RideUploader? uploader;

  final _revision = ValueNotifier(0);

  @override
  ValueListenable<int> get revision => _revision;

  static const _key = 'ride_history';

  /// Keep the file small; older rides drop off.
  static const _max = 200;

  @override
  Future<void> save(RideSummary ride) async {
    final rides = await all();
    await _write([ride, ...rides.where((r) => r.id != ride.id || r.id == '')]);
    await sync();
  }

  @override
  Future<List<RideSummary>> all() async {
    final raw = await SharedPreferencesAsync().getString(_key);
    if (raw == null) return [];
    return [
      for (final r in jsonDecode(raw) as List) RideSummary.fromJson(r as Json),
    ];
  }

  @override
  Future<RideSummary?> byId(String id) async {
    for (final r in await all()) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<bool> sync() async {
    final up = uploader;
    final rides = await all();
    if (up == null) return rides.every((r) => r.synced);
    var changed = false;
    var allDone = true;
    final out = <RideSummary>[];
    for (final r in rides) {
      if (r.synced || r.route == null) {
        out.add(r);
        continue;
      }
      try {
        await up.upload(r);
        out.add(r.copyWith(synced: true, dropRoute: true));
        changed = true;
      } on Exception catch (e) {
        debugPrint('rides: upload of ${r.id} failed: $e');
        out.add(r);
        allDone = false;
      }
    }
    if (changed) await _write(out);
    return allDone;
  }

  @override
  Future<void> markPosted(String id) async {
    final rides = await all();
    await _write([
      for (final r in rides) r.id == id ? r.copyWith(posted: true) : r,
    ]);
  }

  Future<void> _write(List<RideSummary> rides) async {
    await SharedPreferencesAsync().setString(
      _key,
      jsonEncode([for (final r in rides.take(_max)) r.toJson()]),
    );
    _revision.value++;
  }
}
