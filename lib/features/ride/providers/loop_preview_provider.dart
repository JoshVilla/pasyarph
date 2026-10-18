import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/models/generated_loop.dart';
import '../../../data/repositories/route_repository.dart';
import '../loop_stats.dart';

/// What was asked for, so Shuffle can ask again with a new seed.
class LoopRequest {
  const LoopRequest({
    required this.start,
    required this.duration,
    required this.avoidHighways,
    required this.avoidUnpaved,
  });

  final LatLng start;
  final LoopDuration duration;
  final bool avoidHighways;
  final bool avoidUnpaved;
}

/// The loop being previewed. App-wide so the preview screen (and later the
/// ride) can read what Home generated.
class LoopPreviewProvider extends ChangeNotifier {
  LoopPreviewProvider(this._routes, {Random? random})
    : _random = random ?? Random();

  final RouteRepository _routes;
  final Random _random;

  LoopRequest? _request;
  GeneratedLoop? _loop;
  StopInfo? _mainStop;
  bool _loading = false;
  RouteException? _error;

  LoopRequest? get request => _request;
  GeneratedLoop? get loop => _loop;
  StopInfo? get mainStop => _mainStop;

  /// A loop is being fetched. During Shuffle the previous [loop] stays.
  bool get loading => _loading;

  /// Why the last Generate or Shuffle failed; cleared on the next try.
  RouteException? get error => _error;

  /// Ride this loop (Prompt 15): the loop being ridden from a post, else
  /// null for a generated loop.
  String? _rideLoopId;
  String? _rideLoopName;

  bool get isRideThisLoop => _rideLoopId != null;

  /// The top pill: "HALF-DAY LOOP", or the loop's name when riding a post.
  String get title =>
      _rideLoopName?.toUpperCase() ?? '${_request?.duration.title} LOOP';

  /// Home's GENERATE LOOP. Returns true when a loop is ready to preview.
  Future<bool> generate(LoopRequest request) async {
    if (_loading) return false;
    _request = request;
    _rideLoopId = null;
    _rideLoopName = null;
    _loop = null;
    _mainStop = null;
    return _fetch();
  }

  /// RIDE IT on a post: someone else's loop from [start]. Returns true when
  /// it's ready to preview.
  Future<bool> rideLoop({
    required String loopId,
    required String name,
    required LatLng start,
  }) async {
    if (_loading) return false;
    // A ride-this-loop ride has no duration or road options of its own.
    _request = LoopRequest(
      start: start,
      duration: LoopDuration.halfDay,
      avoidHighways: false,
      avoidUnpaved: false,
    );
    _rideLoopId = loopId;
    _rideLoopName = name;
    _loop = null;
    _mainStop = null;
    return _fetch();
  }

  /// New seed, same request. The current loop stays visible until the new
  /// one arrives (or stays for good if it fails). Not for ride this loop.
  Future<bool> shuffle() async {
    if (_loading || _request == null || isRideThisLoop) return false;
    return _fetch();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _fetch() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // Riding to a loop and back on the same road is expected: no reroll.
      final loop = isRideThisLoop
          ? await _routes.rideLoop(loopId: _rideLoopId!, start: _request!.start)
          : await _bestLoop(_request!);
      _loop = loop;
      _mainStop = stopFor(loop);
      return true;
    } on RouteException catch (e) {
      _error = e;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// One loop; if it backtracks too much, up to [extraSeeds] more, keeping
  /// the best. Failures after the first loop just end the search.
  Future<GeneratedLoop> _bestLoop(LoopRequest r) async {
    final candidates = [await _generate(r)];
    for (var i = 0; i < extraSeeds; i++) {
      if (candidates.last.backtrackingRatio <= maxBacktracking) break;
      try {
        candidates.add(await _generate(r));
      } on RouteException {
        break;
      }
    }
    return pickBest(candidates);
  }

  Future<GeneratedLoop> _generate(LoopRequest r) => _routes.generateLoop(
    start: r.start,
    duration: r.duration,
    avoidHighways: r.avoidHighways,
    avoidUnpaved: r.avoidUnpaved,
    seed: _random.nextInt(0x7fffffff),
  );
}
