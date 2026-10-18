import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/links.dart';
import '../../../data/ids.dart';
import '../../../data/models/club.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/loop.dart';
import '../../../data/models/routed_leg.dart';
import '../../../data/repositories/loop_repository.dart';
import '../../../data/repositories/route_repository.dart';
import '../loop_builder.dart';

/// `main_stop.type` for a point the rider picked on the map.
const customStopType = 'custom';

/// The custom loop being drawn in the Create tab: S (the rider's location),
/// numbered points, which one is the main stop, and the legs routed so far.
/// Routes changed legs 600 ms after the last edit.
class CreateLoopController extends ChangeNotifier {
  CreateLoopController({
    required RouteRepository routes,
    required LoopRepository loops,
    this.debounce = routeDebounce,
  }) : _routes = routes,
       _loops = loops;

  final RouteRepository _routes;
  final LoopRepository _loops;
  final Duration debounce;

  LatLng? _start;
  final _points = <LatLng>[];
  int? _mainStop;

  /// Routed legs by [legKey]. Kept across edits, so undoing or moving a
  /// point back costs no routing.
  final _legs = <String, RoutedLeg>{};

  Timer? _timer;
  bool _routing = false;
  bool _routeAgain = false;
  RouteException? _routeError;

  String _name = '';
  LoopVisibility _visibility = LoopVisibility.public;
  List<Club>? _clubs;
  String? _clubId;

  String? _savedId;
  bool _dirty = true;
  bool _saving = false;
  LoopException? _saveError;
  bool _disposed = false;

  /// S: where the loop starts and ends. Null until the first location fix.
  LatLng? get start => _start;
  List<LatLng> get points => List.unmodifiable(_points);
  bool get routing => _routing;
  RouteException? get routeError => _routeError;

  String get name => _name;
  LoopVisibility get visibility => _visibility;

  /// Null until loaded.
  List<Club>? get clubs => _clubs;
  Club? get club => _clubs?.where((c) => c.id == _clubId).firstOrNull;

  /// Set once the loop is saved; saving again updates it.
  String? get savedId => _savedId;

  /// Changed since the last save (or never saved).
  bool get dirty => _dirty;
  bool get saving => _saving;
  LoopException? get saveError => _saveError;

  bool get canAddPoint => _start != null && _points.length < maxLoopPoints;

  /// The main stop point (index into [points]): the rider's pick, else the
  /// point farthest from S.
  int? get mainStopIndex {
    if (_points.isEmpty) return null;
    return _mainStop ?? farthestPointIndex(_start!, _points);
  }

  List<LatLng> get stops => _start == null ? [] : loopStops(_start!, _points);
  LoopShape get shape => loopShape(stops, _legs);
  LoopTotals get totals => loopTotals(stops, _legs);

  /// Ready to save: at least two points, every leg routed, a club picked
  /// for Group.
  bool get canSave =>
      _points.length >= 2 &&
      totals.complete &&
      !_saving &&
      (_visibility != LoopVisibility.club || club != null);

  /// Sets S from the first location fix. Later fixes don't move it.
  void setStart(LatLng start) {
    if (_start != null) return;
    _start = start;
    notifyListeners();
  }

  void addPoint(LatLng point) {
    if (!canAddPoint) return;
    _points.add(point);
    _changed();
  }

  /// Moves point [index] while it's dragged; the route waits for [endDrag].
  void dragPoint(int index, LatLng to) {
    _points[index] = to;
    _dirty = true;
    notifyListeners();
  }

  void endDrag() => _changed();

  void removePoint(int index) {
    _points.removeAt(index);
    _mainStop = mainStopAfterRemoving(_mainStop, index);
    _changed();
  }

  /// Removes the last point.
  void undo() {
    if (_points.isEmpty) return;
    removePoint(_points.length - 1);
  }

  void setMainStop(int index) {
    if (_mainStop == index) return;
    _mainStop = index;
    _dirty = true;
    notifyListeners();
  }

  void setName(String name) {
    if (_name == name) return;
    _name = name;
    _dirty = true;
    notifyListeners();
  }

  void setVisibility(LoopVisibility visibility) {
    if (_visibility == visibility) return;
    _visibility = visibility;
    _dirty = true;
    notifyListeners();
    if (visibility == LoopVisibility.club && _clubs == null) loadClubs();
  }

  void setClub(String clubId) {
    _clubId = clubId;
    _dirty = true;
    notifyListeners();
  }

  /// Loads the rider's clubs and picks the first one for Group.
  Future<void> loadClubs() async {
    try {
      final clubs = await _loops.myClubs();
      if (_disposed) return;
      _clubs = clubs;
      _clubId ??= clubs.firstOrNull?.id;
    } on LoopException {
      if (_disposed) return;
      _clubs = const [];
    }
    notifyListeners();
  }

  /// Routes again after a failure.
  void retryRoute() => _route();

  void _changed() {
    _dirty = true;
    _routeError = null;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(debounce, _route);
  }

  Future<void> _route() async {
    _timer?.cancel();
    if (_routing) {
      _routeAgain = true;
      return;
    }
    final runs = missingRuns(stops, _legs);
    if (runs.isEmpty) return;
    _routing = true;
    _routeError = null;
    notifyListeners();
    try {
      final routed = await _routes.routeThroughPoints(runs);
      for (var r = 0; r < runs.length && r < routed.length; r++) {
        final run = runs[r];
        for (var i = 0; i < run.length - 1 && i < routed[r].length; i++) {
          _legs[legKey(run[i], run[i + 1])] = routed[r][i];
        }
      }
    } on RouteException catch (e) {
      _routeError = e;
    }
    if (_disposed) return;
    _routing = false;
    notifyListeners();
    if (_routeAgain) {
      _routeAgain = false;
      if (_routeError == null) _route();
    }
  }

  /// Saves the loop (insert the first time, update after). False when it
  /// can't be saved yet or saving failed ([saveError]).
  Future<bool> save() async {
    if (!canSave) return false;
    final route = fullRoute(stops, _legs)!;
    final totals = this.totals;
    final stop = mainStopIndex!;
    final metersIn = metersToPoint(_start!, _points, stop, _legs);
    final trimmed = _name.trim();
    final loop = NewLoop(
      name: trimmed.isEmpty ? defaultLoopName(totals.distanceM) : trimmed,
      source: LoopSource.custom,
      route: route,
      distanceM: totals.distanceM,
      durationS: totals.durationS,
      mainStop: MainStop(
        location: _points[stop],
        type: customStopType,
        kmIntoRoute: metersIn == null ? null : (metersIn / 100).round() / 10,
      ),
      visibility: _visibility,
      clubId: _visibility == LoopVisibility.club ? _clubId : null,
    );

    _saving = true;
    _saveError = null;
    notifyListeners();
    try {
      final id = _savedId;
      if (id == null) {
        final newId = createId();
        await _loops.create(newId, loop);
        _savedId = newId;
      } else {
        await _loops.update(id, loop);
      }
      _dirty = false;
    } on LoopException catch (e) {
      _saveError = e;
    }
    if (_disposed) return false;
    _saving = false;
    notifyListeners();
    return _saveError == null;
  }

  /// Private loops have no link to share.
  bool get canShare => _visibility != LoopVisibility.private;

  /// SHARE LINK works now: the loop can be saved, or is saved unchanged.
  bool get canShareNow =>
      canShare && !_saving && (canSave || (!_dirty && _savedId != null));

  /// Saves any changes, then returns the loop's share link, or null when
  /// it couldn't be saved.
  Future<Uri?> shareLink() async {
    if (!canShare) return null;
    if (_dirty || _savedId == null) {
      if (!await save()) return null;
    }
    return AppLinks.loop(_savedId!);
  }

  /// Picks the id for a new loop. Replaceable in tests.
  @visibleForTesting
  String Function() createId = newId;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// Name for a loop saved without one: "62 km loop".
String defaultLoopName(int distanceM) => '${(distanceM / 1000).round()} km loop';
