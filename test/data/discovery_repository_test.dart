import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pasyarph/data/models/loop.dart';
import 'package:pasyarph/data/repositories/discovery_repository.dart';

Map<String, Object?> row(int i) => {
  'id': 'loop-$i',
  'owner_id': 'rider',
  'name': 'Route $i',
  'source': 'custom',
  'distance_m': 82000,
  'duration_s': 10800,
  'visibility': 'public',
  'created_at': '2026-11-01T00:00:00Z',
  'province': 'Rizal',
  'shared_route': {
    'type': 'LineString',
    'coordinates': [
      [121.4, 16.7],
      [121.5, 16.8],
    ],
  },
};

void main() {
  late HttpServer server;
  late SupabaseClient client;
  late Uri requestUri;
  late List<Map<String, Object?>> payload;
  late int status;
  setUp(() async {
    status = 200;
    payload = [row(0)];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requestUri = request.uri;
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(status == 200 ? payload : {'message': 'offline'}),
      );
      await request.response.close();
    });
    client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key');
  });
  tearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });

  test(
    'queries only public rideable loops and explicitly safe columns',
    () async {
      final page = await SupabaseDiscoveryRepository(
        client,
      ).search(const DiscoveryQuery());
      expect(page.loops.single.name, 'Route 0');
      expect(page.hasMore, isFalse);
      expect(requestUri.queryParameters['select'], Loop.columns);
      expect(
        requestUri.queryParameters['select']!.split(','),
        isNot(contains('route')),
      );
      expect(requestUri.queryParameters['visibility'], 'eq.public');
      expect(requestUri.queryParameters['shared_route'], 'not.is.null');
    },
  );

  test(
    'search grammar characters stay quoted and filters are server-side',
    () async {
      await SupabaseDiscoveryRepository(client).search(
        const DiscoveryQuery(
          term: 'Falls, (Rizal) "west"_100%',
          distance: DiscoveryDistance.medium,
          time: DiscoveryTime.medium,
          sort: DiscoverySort.distance,
        ),
        offset: 20,
      );
      final filter = requestUri.queryParameters['or']!;
      expect(filter, contains('main_stop->>name.ilike.'));
      expect(filter, contains(r'\"west\"'));
      expect(filter, contains(r'\\_100\\%'));
      expect(requestUri.queryParametersAll['distance_m'], [
        'gte.50000',
        'lt.150000',
      ]);
      expect(requestUri.queryParametersAll['duration_s'], [
        'gte.7200',
        'lt.14400',
      ]);
      expect(
        requestUri.queryParameters['order'],
        'distance_m.asc.nullslast,created_at.desc.nullslast,id.desc.nullslast',
      );
      expect(requestUri.queryParameters['offset'], '20');
      expect(requestUri.queryParameters['limit'], '21');
    },
  );

  test(
    'fetches one extra result to determine whether another page exists',
    () async {
      payload = [for (var i = 0; i < 21; i++) row(i)];
      final page = await SupabaseDiscoveryRepository(
        client,
      ).search(const DiscoveryQuery());
      expect(page.loops.length, 20);
      expect(page.hasMore, isTrue);
    },
  );

  test('maps server errors to a retryable message', () async {
    status = 503;
    await expectLater(
      SupabaseDiscoveryRepository(client).search(const DiscoveryQuery()),
      throwsA(isA<DiscoveryException>()),
    );
  });
}
