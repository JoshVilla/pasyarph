import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/location/location_permission.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/core/notifications/ride_notifier.dart';
import 'package:pasyarph/data/models/generated_loop.dart';
import 'package:pasyarph/data/models/club.dart';
import 'package:pasyarph/data/models/loop.dart';
import 'package:pasyarph/data/models/routed_leg.dart';
import 'package:pasyarph/data/repositories/avatar_repository.dart';
import 'package:pasyarph/data/repositories/loop_repository.dart';
import 'package:pasyarph/data/repositories/ride_history_repository.dart';
import 'package:pasyarph/data/repositories/route_repository.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';

class FakeAvatarRepository implements AvatarRepository {
  final uploads = <String>[];

  @override
  Future<String> uploadAvatar(String userId, Uint8List jpeg) async {
    uploads.add(userId);
    return 'https://example.test/avatars/$userId/avatar.jpg';
  }
}

class FakeLocationPermission implements LocationPermissionService {
  FakeLocationPermission([this.answer = LocationAccess.granted]);

  LocationAccess answer;
  int requests = 0;

  @override
  Future<LocationAccess> current() async => answer;

  @override
  Future<LocationAccess> requestWhileInUse() async {
    requests++;
    return answer;
  }

  @override
  Future<bool> openSettings() async => true;
}

class FakePositionSource implements PositionSource {
  FakePositionSource({this.enabled = true, this.last});

  bool enabled;
  RiderFix? last;
  int settingsOpened = 0;
  final controller = StreamController<RiderFix>.broadcast();

  void emit(RiderFix fix) => controller.add(fix);

  @override
  Future<bool> serviceEnabled() async => enabled;

  @override
  Future<RiderFix?> lastKnown() async => last;

  bool background = false;

  @override
  Stream<RiderFix> fixes({bool background = false}) {
    this.background = background;
    return controller.stream;
  }

  @override
  Future<bool> openLocationSettings() async {
    settingsOpened++;
    return true;
  }
}

/// Hands out queued results (a [GeneratedLoop] or a [RouteException]), then
/// [demoLoop]. Set [gate] to hold calls until it completes.
class FakeRouteRepository implements RouteRepository {
  FakeRouteRepository([List<Object>? results]) : results = results ?? [];

  final List<Object> results;
  final seeds = <int>[];
  Completer<void>? gate;

  @override
  Future<GeneratedLoop> generateLoop({
    required LatLng start,
    required LoopDuration duration,
    required bool avoidHighways,
    required bool avoidUnpaved,
    required int seed,
  }) async {
    seeds.add(seed);
    await gate?.future;
    final next = results.isEmpty ? demoLoop(seed: seed) : results.removeAt(0);
    if (next is RouteException) throw next;
    return next as GeneratedLoop;
  }

  final rideLoops = <String>[];

  @override
  Future<GeneratedLoop> rideLoop({
    required String loopId,
    required LatLng start,
  }) async {
    rideLoops.add(loopId);
    await gate?.future;
    final next = results.isEmpty
        ? demoLoop(approachM: 3000)
        : results.removeAt(0);
    if (next is RouteException) throw next;
    return next as GeneratedLoop;
  }

  /// Runs sent to routeThroughPoints, one list per call.
  final pointRuns = <List<List<LatLng>>>[];

  /// Next routeThroughPoints call throws this.
  RouteException? failRouteNext;

  /// Leg for a pair of points; defaults to a straight line, 1 km and 2 min
  /// per 0.01° (about).
  RoutedLeg Function(LatLng a, LatLng b) legFor = straightLeg;

  @override
  Future<List<List<RoutedLeg>>> routeThroughPoints(
    List<List<LatLng>> runs,
  ) async {
    pointRuns.add(runs);
    await gate?.future;
    final fail = failRouteNext;
    if (fail != null) {
      failRouteNext = null;
      throw fail;
    }
    return [
      for (final run in runs)
        [for (var i = 0; i < run.length - 1; i++) legFor(run[i], run[i + 1])],
    ];
  }
}

RoutedLeg straightLeg(LatLng a, LatLng b) {
  final m = const Distance().as(LengthUnit.Meter, a, b).round();
  return RoutedLeg(points: [a, b], distanceM: m, durationS: m ~/ 10);
}

/// In-memory loops and clubs.
class FakeLoopRepository implements LoopRepository {
  FakeLoopRepository({List<Club>? clubs}) : clubs = clubs ?? [];

  final List<Club> clubs;
  final saved = <String, NewLoop>{};
  final calls = <String>[];
  final _revision = ValueNotifier(0);

  /// Next write throws this.
  LoopException? failNext;

  @override
  ValueListenable<int> get revision => _revision;

  void _write(String call, String id, NewLoop loop) {
    calls.add('$call:$id');
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    saved[id] = loop;
    _revision.value++;
  }

  @override
  Future<void> create(String id, NewLoop loop) async =>
      _write('create', id, loop);

  @override
  Future<void> update(String id, NewLoop loop) async =>
      _write('update', id, loop);

  @override
  Future<List<Loop>> mine() async => [
    for (final MapEntry(key: id, value: l) in saved.entries)
      Loop(
        id: id,
        ownerId: 'me',
        name: l.name,
        source: l.source,
        sharedRoute: l.distanceM > 1800 ? l.route : null,
        distanceM: l.distanceM,
        durationS: l.durationS,
        mainStop: l.mainStop,
        visibility: l.visibility,
        clubId: l.clubId,
        createdAt: DateTime(2026, 10, 19),
      ),
  ];

  @override
  Future<List<Club>> myClubs() async => clubs;
}

/// The mockup's half-day loop: 118 km, 3 h 50, curvy.
GeneratedLoop demoLoop({
  int seed = 1,
  int distanceM = 118000,
  int approachM = 0,
  double backtracking = 0.02,
  double curviness = 340,
  List<String> warnings = const [],
  MainStop? mainStop,
  List<FuelStop> fuel = const [],
}) => GeneratedLoop(
  route: DemoRoutes.loop,
  distanceM: distanceM,
  approachM: approachM,
  durationS: 13800,
  steps: const [],
  seed: seed,
  backtrackingRatio: backtracking,
  curvinessScore: curviness,
  warnings: warnings,
  mainStop: mainStop,
  fuelStops: fuel,
);

/// The mockup's main stop: a named viewpoint 52 km in, with fuel nearby.
final demoStop = MainStop(
  location: DemoRoutes.mainStop,
  name: 'Mt. Palali Viewpoint',
  type: 'viewpoint',
  kmIntoRoute: 52,
);
final demoFuel = [
  FuelStop(location: DemoRoutes.point2, name: 'Petron', kmIntoRoute: 40),
];

class FakeRideNotifier implements RideNotifier {
  final events = <String>[];

  @override
  Future<void> prepare() async => events.add('prepare');

  @override
  Future<void> arrivedAtStop(String stopName) async =>
      events.add('stop:$stopName');

  @override
  Future<void> leftLoop() async => events.add('left');

  @override
  Future<void> backOnLoop() async => events.add('back');

  @override
  Future<void> backHome() async => events.add('home');

  @override
  Future<void> clearAlerts() async => events.add('clear');

  @override
  Future<void> rideFinished(String summary) async =>
      events.add('finished:$summary');
}

class FakeRideHistory implements RideHistoryRepository {
  final saved = <RideSummary>[];
  final _revision = ValueNotifier(0);

  @override
  ValueListenable<int> get revision => _revision;

  @override
  Future<void> save(RideSummary ride) async {
    saved.insert(0, ride);
    _revision.value++;
  }

  @override
  Future<RideSummary?> byId(String id) async =>
      saved.where((r) => r.id == id).firstOrNull;

  @override
  Future<bool> sync() async => true;

  @override
  Future<void> markPosted(String id) async {
    final i = saved.indexWhere((r) => r.id == id);
    if (i >= 0) saved[i] = saved[i].copyWith(posted: true);
    _revision.value++;
  }

  @override
  Future<List<RideSummary>> all() async => saved;
}
