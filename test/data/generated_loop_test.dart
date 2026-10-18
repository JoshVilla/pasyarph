import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/data/models/generated_loop.dart';
import 'package:pasyarph/data/repositories/route_repository.dart';

void main() {
  test('durations send the values generate-loop expects', () {
    expect(LoopDuration.values.map((d) => d.value), ['quick', 'half', 'full']);
  });

  test('parses a generate-loop response', () {
    final loop = GeneratedLoop.fromJson({
      'route': {
        'type': 'LineString',
        'coordinates': [
          [121.457, 16.672],
          [121.46, 16.68],
          [121.457, 16.672],
        ],
      },
      'distance_m': 52346,
      'duration_s': 4000,
      'steps': [
        {
          'instruction': 'Turn right onto Maharlika Highway',
          'name': 'Maharlika Highway',
          'distance_m': 1000,
          'duration_s': 61,
          'sign': 2,
          'way_points': [0, 1],
        },
      ],
      'seed': 12,
      'backtracking_ratio': 0.042,
      'curviness_score': 88.5,
      'motorway_m': 0,
      'unpaved_m': 1200,
      'warnings': ['Avoid unpaved isn\'t available yet.'],
    });

    expect(loop.route.first, const LatLng(16.672, 121.457));
    expect(loop.route, hasLength(3));
    expect(loop.distanceM, 52346);
    expect(loop.steps.single.name, 'Maharlika Highway');
    expect(loop.steps.single.toIndex, 1);
    expect(loop.seed, 12);
    expect(loop.backtrackingRatio, 0.042);
    expect(loop.curvinessScore, 88.5);
    expect(loop.steps.single.sign, 2);
    expect(loop.unpavedM, 1200);
    expect(loop.warnings, hasLength(1));
  });

  test('reads friendly errors from the function body', () {
    final e = RouteException.fromBody({
      'error': {'code': 'limit_reached', 'message': 'Take a break.'},
    });
    expect(e.code, 'limit_reached');
    expect(e.message, 'Take a break.');
    expect(RouteException.fromBody('Bad Gateway'), RouteException.unknown);
  });
}
