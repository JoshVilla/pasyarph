import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/models/loop.dart';
import 'package:pasyarph/data/repositories/discovery_repository.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';

Loop discoveryLoop(
  String id, {
  String name = 'Sierra Madre morning',
  String province = 'Rizal',
  int distance = 82000,
  int duration = 10800,
}) => Loop(
  id: id,
  ownerId: 'other',
  name: name,
  source: LoopSource.custom,
  distanceM: distance,
  durationS: duration,
  visibility: LoopVisibility.public,
  createdAt: DateTime.utc(2026, 11, 1),
  province: province,
  sharedRoute: DemoRoutes.loop,
  mainStop: MainStop(
    location: DemoRoutes.mainStop,
    name: 'Mountain viewpoint',
    type: 'viewpoint',
  ),
);

class FakeDiscoveryRepository implements DiscoveryRepository {
  FakeDiscoveryRepository([List<Loop>? routes])
    : routes = routes ?? [discoveryLoop('one')];
  final List<Loop> routes;
  final calls = <(DiscoveryQuery, int)>[];
  bool fail = false;
  int pageSize = 20;
  @override
  Future<DiscoveryPage> search(DiscoveryQuery query, {int offset = 0}) async {
    calls.add((query, offset));
    if (fail) throw const DiscoveryException();
    final term = query.term.toLowerCase();
    final matching = routes
        .where(
          (loop) =>
              loop.visibility == LoopVisibility.public &&
              loop.sharedRoute != null &&
              [
                loop.name,
                loop.province ?? '',
                loop.mainStop?.name ?? '',
              ].any((text) => text.toLowerCase().contains(term)) &&
              (query.distance.min == null ||
                  loop.distanceM >= query.distance.min!) &&
              (query.distance.max == null ||
                  loop.distanceM < query.distance.max!) &&
              (query.time.min == null || loop.durationS >= query.time.min!) &&
              (query.time.max == null || loop.durationS < query.time.max!),
        )
        .toList();
    matching.sort(
      (a, b) => switch (query.sort) {
        DiscoverySort.newest => b.createdAt.compareTo(a.createdAt),
        DiscoverySort.distance => a.distanceM.compareTo(b.distanceM),
        DiscoverySort.time => a.durationS.compareTo(b.durationS),
      },
    );
    return DiscoveryPage(
      matching.skip(offset).take(pageSize).toList(),
      hasMore: matching.length > offset + pageSize,
    );
  }
}
