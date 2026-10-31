import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/loop.dart';

enum DiscoveryDistance {
  any('Any distance', null, null),
  short('Under 50 km', null, 50000),
  medium('50–150 km', 50000, 150000),
  long('150+ km', 150000, null);

  const DiscoveryDistance(this.label, this.min, this.max);
  final String label;
  final int? min, max;
}

enum DiscoveryTime {
  any('Any ride time', null, null),
  short('Under 2 hours', null, 7200),
  medium('2–4 hours', 7200, 14400),
  long('4+ hours', 14400, null);

  const DiscoveryTime(this.label, this.min, this.max);
  final String label;
  final int? min, max;
}

enum DiscoverySort {
  newest('Newest first'),
  distance('Shortest distance'),
  time('Shortest ride time');

  const DiscoverySort(this.label);
  final String label;
}

class DiscoveryQuery {
  const DiscoveryQuery({
    this.term = '',
    this.distance = DiscoveryDistance.any,
    this.time = DiscoveryTime.any,
    this.sort = DiscoverySort.newest,
  });
  final String term;
  final DiscoveryDistance distance;
  final DiscoveryTime time;
  final DiscoverySort sort;
  bool get filtered =>
      term.isNotEmpty ||
      distance != DiscoveryDistance.any ||
      time != DiscoveryTime.any;
  DiscoveryQuery copyWith({
    String? term,
    DiscoveryDistance? distance,
    DiscoveryTime? time,
    DiscoverySort? sort,
  }) => DiscoveryQuery(
    term: term ?? this.term,
    distance: distance ?? this.distance,
    time: time ?? this.time,
    sort: sort ?? this.sort,
  );
}

class DiscoveryPage {
  const DiscoveryPage(this.loops, {required this.hasMore});
  final List<Loop> loops;
  final bool hasMore;
}

class DiscoveryException implements Exception {
  const DiscoveryException();
  String get message =>
      "Couldn't load routes. Check your connection and try again.";
}

abstract interface class DiscoveryRepository {
  Future<DiscoveryPage> search(DiscoveryQuery query, {int offset = 0});
}

class SupabaseDiscoveryRepository implements DiscoveryRepository {
  SupabaseDiscoveryRepository(this._client);
  final SupabaseClient _client;
  static const pageSize = 20;

  @override
  Future<DiscoveryPage> search(DiscoveryQuery query, {int offset = 0}) async {
    try {
      // Explicit safe columns preserve the 800 m home-privacy trim. RLS
      // applies the existing visibility, author-block and item-block rules.
      var request = _client
          .from('loops')
          .select(Loop.columns)
          .eq('visibility', 'public')
          .not('shared_route', 'is', null);
      final term = query.term.trim();
      if (term.isNotEmpty) {
        // Quote the entire filter value, escaping grammar and LIKE wildcards.
        // Commas, parentheses and quotes in a place name stay literal text.
        final escaped = term
            .replaceAll(r'\', r'\\')
            .replaceAll('%', r'\%')
            .replaceAll('_', r'\_')
            .replaceAll('*', r'\*');
        final pattern = jsonEncode('%$escaped%');
        request = request.or(
          'name.ilike.$pattern,province.ilike.$pattern,main_stop->>name.ilike.$pattern',
        );
      }
      final distance = query.distance, time = query.time;
      if (distance.min != null) {
        request = request.gte('distance_m', distance.min!);
      }
      if (distance.max != null) {
        request = request.lt('distance_m', distance.max!);
      }
      if (time.min != null) request = request.gte('duration_s', time.min!);
      if (time.max != null) request = request.lt('duration_s', time.max!);
      var ordered = switch (query.sort) {
        DiscoverySort.newest => request.order('created_at', ascending: false),
        DiscoverySort.distance =>
          request
              .order('distance_m', ascending: true)
              .order('created_at', ascending: false),
        DiscoverySort.time =>
          request
              .order('duration_s', ascending: true)
              .order('created_at', ascending: false),
      };
      final rows = await ordered
          .order('id', ascending: false)
          .range(offset, offset + pageSize);
      return DiscoveryPage([
        for (final row in rows.take(pageSize)) Loop.fromJson(row),
      ], hasMore: rows.length > pageSize);
    } on Exception {
      throw const DiscoveryException();
    }
  }
}
