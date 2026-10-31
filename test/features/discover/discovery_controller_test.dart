import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/data/repositories/discovery_repository.dart';
import 'package:pasyarph/features/discover/providers/discovery_controller.dart';
import '../../support/fake_discovery.dart';

class PendingRepository implements DiscoveryRepository {
  final pending = <Completer<DiscoveryPage>>[];
  @override
  Future<DiscoveryPage> search(DiscoveryQuery query, {int offset = 0}) {
    final completer = Completer<DiscoveryPage>();
    pending.add(completer);
    return completer.future;
  }
}

void main() {
  test('ignores an earlier response after criteria change', () async {
    final repo = PendingRepository();
    final controller = DiscoveryController(repo);
    final first = controller.refresh();
    controller.change(const DiscoveryQuery(term: 'Rizal'));
    repo.pending[1].complete(
      DiscoveryPage([discoveryLoop('new')], hasMore: false),
    );
    await Future<void>.delayed(Duration.zero);
    repo.pending[0].complete(
      DiscoveryPage([discoveryLoop('old')], hasMore: true),
    );
    await first;
    expect(controller.loops.single.id, 'new');
    expect(controller.hasMore, isFalse);
    controller.dispose();
  });

  testWidgets('typing is debounced, and submit cancels the pending request', (
    tester,
  ) async {
    final repo = FakeDiscoveryRepository();
    final controller = DiscoveryController(repo);
    controller.searchText('R');
    controller.searchText('Ri');
    controller.searchText('Rizal');
    await tester.pump(const Duration(milliseconds: 349));
    expect(repo.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repo.calls.single.$1.term, 'Rizal');
    controller.searchText('Baguio');
    await controller.refresh();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.calls.length, 2);
    controller.dispose();
  });

  test('pagination failure keeps routes and retries the same page', () async {
    final repo = FakeDiscoveryRepository([
      for (var i = 0; i < 5; i++) discoveryLoop('loop-$i'),
    ])..pageSize = 2;
    final controller = DiscoveryController(repo);
    await controller.refresh();
    repo.fail = true;
    await controller.loadMore();
    expect(controller.loops.length, 2);
    expect(controller.error, isNotNull);
    expect(controller.hasMore, isTrue);
    repo.fail = false;
    await controller.loadMore();
    expect(repo.calls.last.$2, 2);
    expect(controller.loops.length, 4);
    expect(controller.error, isNull);
    await controller.loadMore();
    expect(controller.loops.length, 5);
    expect(controller.hasMore, isFalse);
    controller.dispose();
  });

  test('filters reset pagination and do not retain stale results', () async {
    final repo = FakeDiscoveryRepository([
      discoveryLoop('short', distance: 30000),
      discoveryLoop('long', distance: 160000),
    ]);
    final controller = DiscoveryController(repo);
    await controller.refresh();
    controller.change(const DiscoveryQuery(distance: DiscoveryDistance.short));
    expect(controller.loops, isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(controller.loops.single.id, 'short');
    expect(repo.calls.last.$2, 0);
    controller.dispose();
  });

  test('responses after disposal do not notify', () async {
    final repo = PendingRepository();
    final controller = DiscoveryController(repo);
    final pending = controller.refresh();
    controller.dispose();
    repo.pending.single.complete(const DiscoveryPage([], hasMore: false));
    await pending;
  });
}
