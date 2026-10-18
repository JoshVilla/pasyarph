import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/json.dart';

/// One finished ride, kept on the phone (the Me tab totals come later).
class RideSummary {
  const RideSummary({
    required this.startedAt,
    required this.endedAt,
    required this.riddenM,
    required this.loopM,
    required this.reachedStop,
    this.stopName,
  });

  final DateTime startedAt;
  final DateTime endedAt;

  /// Distance actually ridden (GPS track).
  final double riddenM;

  /// Planned loop length.
  final int loopM;
  final String? stopName;
  final bool reachedStop;

  Duration get duration => endedAt.difference(startedAt);

  factory RideSummary.fromJson(Json json) => RideSummary(
    startedAt: DateTime.parse(json['started_at'] as String),
    endedAt: DateTime.parse(json['ended_at'] as String),
    riddenM: (json['ridden_m'] as num).toDouble(),
    loopM: (json['loop_m'] as num).toInt(),
    stopName: json['stop_name'] as String?,
    reachedStop: json['reached_stop'] as bool? ?? false,
  );

  Json toJson() => {
    'started_at': startedAt.toIso8601String(),
    'ended_at': endedAt.toIso8601String(),
    'ridden_m': riddenM,
    'loop_m': loopM,
    'stop_name': stopName,
    'reached_stop': reachedStop,
  };
}

abstract interface class RideHistoryRepository {
  Future<void> save(RideSummary ride);
  Future<List<RideSummary>> all();
}

class LocalRideHistoryRepository implements RideHistoryRepository {
  static const _key = 'ride_history';

  /// Keep the file small; older rides drop off.
  static const _max = 200;

  @override
  Future<void> save(RideSummary ride) async {
    final prefs = SharedPreferencesAsync();
    final rides = await all();
    final kept = [ride, ...rides].take(_max).map((r) => r.toJson()).toList();
    await prefs.setString(_key, jsonEncode(kept));
  }

  @override
  Future<List<RideSummary>> all() async {
    final raw = await SharedPreferencesAsync().getString(_key);
    if (raw == null) return [];
    return [
      for (final r in jsonDecode(raw) as List) RideSummary.fromJson(r as Json),
    ];
  }
}
