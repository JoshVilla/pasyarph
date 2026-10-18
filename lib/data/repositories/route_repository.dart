import 'dart:async';
import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/generated_loop.dart';
import '../models/json.dart';
import '../models/routed_leg.dart';

/// Why a loop couldn't be generated. [message] is safe to show riders.
class RouteException implements Exception {
  const RouteException(this.code, this.message);

  /// `limit_reached`, `no_route`, `too_long`, `loop_not_found`, `off_road`
  /// (route-through-points), `routing_busy`, `routing_down`,
  /// `unauthorized`, `bad_request`, or `offline` (no connection from the
  /// phone).
  final String code;
  final String message;

  static const offline = RouteException(
    'offline',
    "You're offline. Connect to the internet to generate a loop.",
  );
  static const unknown = RouteException(
    'unknown',
    "Couldn't generate a loop. Try again.",
  );

  /// Reads the `{error: {code, message}}` body generate-loop sends.
  static RouteException fromBody(Object? body) {
    if (body case {
      'error': {'code': final String c, 'message': final String m},
    }) {
      return RouteException(c, m);
    }
    return unknown;
  }

  @override
  String toString() => 'RouteException($code): $message';
}

abstract interface class RouteRepository {
  /// Asks the generate-loop Edge Function for a loop that starts and ends at
  /// [start]. Throws [RouteException].
  Future<GeneratedLoop> generateLoop({
    required LatLng start,
    required LoopDuration duration,
    required bool avoidHighways,
    required bool avoidUnpaved,
    required int seed,
  });

  /// Ride this loop: someone else's loop [loopId] ridden from [start] (to
  /// the loop, round it, and back). Throws [RouteException]
  /// (`loop_not_found` when it's gone or private).
  Future<GeneratedLoop> rideLoop({
    required String loopId,
    required LatLng start,
  });

  /// Create tab: snaps each run of points to roads (route-through-points
  /// Edge Function). Returns one list per run with a leg per pair of
  /// consecutive points. Throws [RouteException].
  Future<List<List<RoutedLeg>>> routeThroughPoints(List<List<LatLng>> runs);
}

class SupabaseRouteRepository implements RouteRepository {
  SupabaseRouteRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<GeneratedLoop> generateLoop({
    required LatLng start,
    required LoopDuration duration,
    required bool avoidHighways,
    required bool avoidUnpaved,
    required int seed,
  }) => _invoke({
    'lat': start.latitude,
    'lng': start.longitude,
    'duration': duration.value,
    'avoidHighways': avoidHighways,
    'avoidUnpaved': avoidUnpaved,
    'seed': seed,
  });

  @override
  Future<GeneratedLoop> rideLoop({
    required String loopId,
    required LatLng start,
  }) => _invoke({
    'loop_id': loopId,
    'lat': start.latitude,
    'lng': start.longitude,
  });

  @override
  Future<List<List<RoutedLeg>>> routeThroughPoints(List<List<LatLng>> runs) =>
      _call(
        'route-through-points',
        {
          'runs': [
            for (final run in runs)
              [
                for (final p in run) [p.longitude, p.latitude],
              ],
          ],
        },
        (data) => [
          for (final run in (data as Json)['runs'] as List)
            [for (final leg in run as List) RoutedLeg.fromJson(leg as Json)],
        ],
      );

  Future<GeneratedLoop> _invoke(Json body) => _call(
    'generate-loop',
    body,
    (data) => GeneratedLoop.fromJson(data as Json),
  );

  Future<T> _call<T>(
    String function,
    Json body,
    T Function(Object? data) parse,
  ) async {
    try {
      final res = await _client.functions.invoke(function, body: body);
      return parse(res.data);
    } on FunctionException catch (e) {
      throw RouteException.fromBody(e.details);
    } on SocketException {
      throw RouteException.offline;
    } on TimeoutException {
      throw RouteException.offline;
    } on Exception catch (e) {
      // http's ClientException wraps socket errors and isn't exported here.
      if (e.toString().contains('SocketException')) {
        throw RouteException.offline;
      }
      throw RouteException.unknown;
    } on TypeError {
      // Response body didn't have the expected shape.
      throw RouteException.unknown;
    }
  }
}
