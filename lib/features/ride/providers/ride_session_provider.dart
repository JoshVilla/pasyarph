import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/notifications/ride_notifier.dart';
import '../../../data/models/generated_loop.dart';
import '../../../data/repositories/ride_history_repository.dart';
import '../loop_stats.dart';
import '../ride_logic.dart';
import 'loop_preview_provider.dart';

enum RidePhase { idle, riding, finished }

/// A ride navigated in Google Maps. Pasyar keeps tracking in the background
/// to notice the main stop (and later offer photos) and the return home,
/// then saves a summary.
class RideSessionProvider extends ChangeNotifier {
  RideSessionProvider({
    required LocationProvider location,
    required RideNotifier notifier,
    required RideHistoryRepository history,
    Future<bool> Function(Uri url)? openUrl,
    DateTime Function()? clock,
    this.tickEvery = const Duration(seconds: 5),
  }) : _location = location,
       _notifier = notifier,
       _history = history,
       _openUrl = openUrl ?? _launchExternal,
       _now = clock ?? DateTime.now;

  final LocationProvider _location;
  final RideNotifier _notifier;
  final RideHistoryRepository _history;
  final Future<bool> Function(Uri) _openUrl;
  final DateTime Function() _now;

  /// GPS sends nothing while the rider stands still, so this re-checks the
  /// stop and home rules on a timer. Null turns the timer off (tests call
  /// [tick]).
  final Duration? tickEvery;
  Timer? _ticker;
  DateTime? _lastFixAt;

  /// No fix for this long: the rider isn't moving.
  static const _staleFix = Duration(seconds: 6);

  static Future<bool> _launchExternal(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  /// Track points closer than this to the last one are skipped (GPS jitter).
  static const _minStepM = 10.0;

  /// Fixes this far off the loop don't move the rider along it.
  static const _maxOffRouteM = 300.0;

  /// The return home only counts once past this share of the loop (or after
  /// the main stop), so leaving home doesn't end the ride.
  static const _homeArmedShare = 0.5;

  static const _distance = Distance();

  RidePhase _phase = RidePhase.idle;
  GeneratedLoop? _loop;
  StopInfo? _stop;
  LoopRequest? _request;
  RouteTracker? _tracker;
  DwellDetector? _atStop;
  DwellDetector? _atHome;
  DateTime? _startedAt;
  DateTime? _endedAt;
  final _track = <LatLng>[];
  double _riddenM = 0;
  double _alongM = 0;
  double _stopAlongM = 0;
  bool _reachedStop = false;
  RideSummary? _summary;
  bool _mapsOpened = true;

  RidePhase get phase => _phase;
  bool get active => _phase == RidePhase.riding;
  GeneratedLoop? get loop => _loop;
  StopInfo? get stop => _stop;
  LoopRequest? get request => _request;
  bool get reachedStop => _reachedStop;
  double get riddenM => _riddenM;
  List<LatLng> get track => List.unmodifiable(_track);
  RideSummary? get summary => _summary;

  /// False when Google Maps couldn't be opened (not installed).
  bool get mapsOpened => _mapsOpened;

  double get speedKmh => _location.speedKmh;
  LatLng? get position => _location.position;

  Duration get elapsed => (_endedAt ?? _now()).difference(_startedAt ?? _now());

  /// Distance along the loop to the main stop; null once reached.
  double? get toStopM =>
      _reachedStop ? null : (_stopAlongM - _alongM).clamp(0, double.infinity);

  /// The loop split where the rider is: ridden part and the rest.
  ({List<LatLng> behind, List<LatLng> ahead})? get split {
    final loop = _loop;
    if (loop == null) return null;
    return _tracker!.splitAt(loop.route, _alongM);
  }

  Future<void> start({
    required GeneratedLoop loop,
    required StopInfo stop,
    required LoopRequest request,
  }) async {
    if (active) return;
    _loop = loop;
    _stop = stop;
    _request = request;
    _tracker = RouteTracker(loop.route);
    _stopAlongM = _tracker!.locate(stop.location).alongM;
    _atStop = DwellDetector(target: stop.location);
    _atHome = DwellDetector(target: loop.route.first, radiusM: 200);
    _startedAt = _now();
    _endedAt = null;
    _track.clear();
    // Count from where the rider is now, not from the next fix.
    final here = _location.position;
    if (here != null) _track.add(here);
    _riddenM = 0;
    _alongM = 0;
    _reachedStop = false;
    _summary = null;
    _phase = RidePhase.riding;
    notifyListeners();

    await _notifier.prepare();
    await _location.setBackground(true);
    _location.addListener(_onLocation);
    if (tickEvery != null) _ticker = Timer.periodic(tickEvery!, (_) => tick());
    await openMaps();
  }

  /// Opens (or returns to) Google Maps navigation for the loop.
  Future<void> openMaps() async {
    final loop = _loop;
    if (loop == null) return;
    final url = googleMapsLink(
      route: loop.route,
      mainStop: _stop?.location,
      avoidHighways: _request?.avoidHighways ?? false,
    );
    bool opened;
    try {
      opened = await _openUrl(url);
    } on Exception {
      opened = false;
    }
    if (opened != _mapsOpened) {
      _mapsOpened = opened;
      notifyListeners();
    }
  }

  void _onLocation() {
    final pos = _location.position;
    if (!active || pos == null) return;
    _lastFixAt = _now();

    if (_track.isEmpty || _distance(_track.last, pos) >= _minStepM) {
      if (_track.isNotEmpty) _riddenM += _distance(_track.last, pos);
      _track.add(pos);
    }
    final at = _tracker!.locate(pos, near: _alongM);
    if (at.offRouteM <= _maxOffRouteM) _alongM = at.alongM;
    _evaluate(pos, speedKmh);
  }

  /// Re-checks the stop and home rules without a new fix.
  @visibleForTesting
  void tick() {
    final pos = _location.position;
    if (!active || pos == null) return;
    final stale =
        _lastFixAt == null || _now().difference(_lastFixAt!) > _staleFix;
    _evaluate(pos, stale ? 0 : speedKmh);
  }

  void _evaluate(LatLng pos, double speedKmh) {
    final now = _now();
    if (!_reachedStop && _atStop!.update(pos, speedKmh, now)) {
      _reachedStop = true;
      _notifier.arrivedAtStop(_stop!.title);
    }

    final length = _tracker!.lengthM;
    final homeArmed =
        _reachedStop ||
        _alongM > length * _homeArmedShare ||
        _riddenM > length * _homeArmedShare;
    if (homeArmed && _atHome!.update(pos, speedKmh, now)) {
      _finish(auto: true);
      return;
    }
    notifyListeners();
  }

  /// END RIDE.
  Future<void> end() => _finish(auto: false);

  Future<void> _finish({required bool auto}) async {
    if (!active) return;
    _phase = RidePhase.finished;
    _endedAt = _now();
    _ticker?.cancel();
    _ticker = null;
    _location.removeListener(_onLocation);
    final summary = RideSummary(
      startedAt: _startedAt!,
      endedAt: _endedAt!,
      riddenM: _riddenM,
      loopM: _loop!.distanceM,
      stopName: _stop?.title,
      reachedStop: _reachedStop,
    );
    _summary = summary;
    notifyListeners();

    await _location.setBackground(false);
    await _history.save(summary);
    if (auto) {
      await _notifier.rideFinished(
        '${formatDistance(summary.riddenM.round())} in '
        '${formatRideTime(summary.duration.inSeconds)}',
      );
    }
  }

  /// After the summary: back to idle for the next ride.
  void close() {
    if (active) return;
    _phase = RidePhase.idle;
    _loop = null;
    _summary = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _location.removeListener(_onLocation);
    super.dispose();
  }
}
