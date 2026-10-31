import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/data/ids.dart';
import 'package:pasyarph/data/repositories/ride_history_repository.dart';
import 'package:pasyarph/features/me/widgets/ride_history_list.dart';
import 'package:provider/provider.dart';

import '../../support/fake_services.dart';

RideSummary _ride({double ridden = 40000, bool posted = false}) => RideSummary(
  id: newId(),
  startedAt: DateTime.now().subtract(const Duration(hours: 4)),
  endedAt: DateTime.now().subtract(const Duration(hours: 1)),
  riddenM: ridden,
  loopM: 50000,
  stop: const RideStop(
    location: LatLng(16.7, 121.46),
    type: 'waterfall',
    name: 'Talon',
  ),
  reachedStop: true,
  synced: true,
  posted: posted,
);

Widget _list(FakeRideHistory history) => Provider<RideHistoryRepository>.value(
  value: history,
  child: const MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: RideHistoryList())),
  ),
);

void main() {
  testWidgets('a ride saved while the Me tab is open shows up (POST LATER)', (
    tester,
  ) async {
    final history = FakeRideHistory();
    await tester.pumpWidget(_list(history));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Rides you finish show up here'),
      findsOneWidget,
    );

    await history.save(_ride());
    await tester.pumpAndSettle();
    expect(find.text('Talon'), findsOneWidget);
    expect(find.textContaining('NOT POSTED YET'), findsOneWidget);
    expect(find.text('POST'), findsOneWidget);
  });

  testWidgets('postable rides first; posted and short ones have no POST', (
    tester,
  ) async {
    final history = FakeRideHistory();
    await history.save(_ride());
    await history.save(_ride(posted: true));
    await history.save(_ride(ridden: 5000));
    await tester.pumpWidget(_list(history));
    await tester.pumpAndSettle();
    expect(find.text('POST'), findsOneWidget);
    expect(
      find.textContaining('POSTED'),
      findsNWidgets(2),
    ); // incl. NOT POSTED YET
    expect(find.textContaining('TOO SHORT TO POST'), findsOneWidget);
    final first = tester.getTopLeft(find.textContaining('NOT POSTED YET')).dy;
    final posted = tester.getTopLeft(find.text('POSTED')).dy;
    expect(first, lessThan(posted));
  });

  testWidgets('ride cards fit a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final history = FakeRideHistory();
    await history.save(_ride());
    await tester.pumpWidget(_list(history));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Distance ridden'), findsOneWidget);
    expect(find.text('Ride time'), findsOneWidget);
    expect(find.text('POST'), findsOneWidget);
  });
  group('delete', () {
    Future<void> openDelete(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete ride'));
      await tester.pumpAndSettle();
    }

    testWidgets('⋯ → Delete ride asks, then removes it', (tester) async {
      final history = FakeRideHistory();
      await history.save(_ride());
      await tester.pumpWidget(_list(history));
      await tester.pumpAndSettle();

      await openDelete(tester);
      expect(find.text('Delete this ride?'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(history.saved, hasLength(1));

      await openDelete(tester);
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();
      expect(history.saved, isEmpty);
      expect(find.text('Talon'), findsNothing);
      expect(find.text('Ride deleted.'), findsOneWidget);
    });

    testWidgets('a posted ride: the post stays', (tester) async {
      final history = FakeRideHistory();
      await history.save(_ride(posted: true));
      await tester.pumpWidget(_list(history));
      await tester.pumpAndSettle();
      await openDelete(tester);
      expect(find.textContaining('Your post stays.'), findsOneWidget);
    });

    testWidgets('offline: says so and keeps the ride', (tester) async {
      final history = FakeRideHistory()
        ..failDelete = RideHistoryException.deleteFailed;
      await history.save(_ride());
      await tester.pumpWidget(_list(history));
      await tester.pumpAndSettle();
      await openDelete(tester);
      await tester.tap(find.text('DELETE'));
      await tester.pumpAndSettle();
      expect(
        find.text(RideHistoryException.deleteFailed.message),
        findsOneWidget,
      );
      expect(find.text('Talon'), findsOneWidget);
    });
  });
}
