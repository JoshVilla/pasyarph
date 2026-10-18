import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/core/widgets/widgets.dart';
import 'package:pasyarph/data/ids.dart';
import 'package:pasyarph/data/repositories/post_repository.dart';
import 'package:pasyarph/data/repositories/ride_history_repository.dart';
import 'package:pasyarph/features/dev/demo_routes.dart';
import 'package:pasyarph/features/post/post_draft.dart';
import 'package:pasyarph/features/post/providers/post_composer.dart';
import 'package:pasyarph/features/post/screens/post_loop_screen.dart';
import 'package:provider/provider.dart';

import '../../support/fake_post.dart';
import '../../support/fake_services.dart';

const _screen = BoxConstraints.tightFor(width: 390, height: 844);

/// The mockup's ride: Bangaan View, a 118 km loop, 3 h 50.
RideSummary _ride() => RideSummary(
  id: newId(),
  startedAt: DateTime.now().subtract(const Duration(hours: 5)),
  endedAt: DateTime.now().subtract(const Duration(hours: 1)),
  riddenM: 117000,
  loopM: 118000,
  loopDurationS: 3 * 3600 + 50 * 60,
  stop: RideStop(
    location: DemoRoutes.mainStop,
    type: 'viewpoint',
    name: 'Bangaan View',
  ),
  reachedStop: true,
  preview: DemoRoutes.loop,
  synced: true,
);

/// Four photo files in the mockup's placeholder colors.
List<DraftPhoto> _photos(Directory dir) {
  const colors = [
    (0xB9, 0xC7, 0xB0),
    (0x9F, 0xB4, 0xC4),
    (0xC9, 0xB7, 0x9C),
    (0xA8, 0xB3, 0xA0),
  ];
  return [
    for (final (i, (r, g, b)) in colors.indexed)
      DraftPhoto(
        path:
            (File('${dir.path}/$i.jpg')..writeAsBytesSync(
                  img.encodeJpg(
                    img.fill(
                      img.Image(width: 64, height: 64),
                      color: img.ColorRgb8(r, g, b),
                    ),
                  ),
                ))
                .path,
        width: 64,
        height: 64,
      ),
  ];
}

Widget _app({
  required FakeRideHistory history,
  required MemoryDrafts drafts,
  required RideSummary ride,
  PostRepository? posts,
  PhotoPicker? pick,
}) {
  final location = LocationProvider(
    permissions: FakeLocationPermission(),
    positions: FakePositionSource(last: RiderFix(point: DemoRoutes.start)),
  );
  return MultiProvider(
    providers: [
      Provider<RideHistoryRepository>.value(value: history),
      Provider<PostRepository>.value(value: posts ?? FakePosts()),
      Provider<PostDraftStore>.value(value: drafts),
      ChangeNotifierProvider.value(value: location),
    ],
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 44),
          viewPadding: const EdgeInsets.only(top: 44),
        ),
        child: PostLoopScreen(
          rideId: ride.id,
          pick: pick ?? ({required camera, required max}) async => [],
        ),
      ),
    ),
  );
}

void main() {
  late Directory tmp;
  late FakeRideHistory history;
  late MemoryDrafts drafts;
  late RideSummary ride;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pasyar_post_screen');
    history = FakeRideHistory();
    drafts = MemoryDrafts(tmp);
    ride = _ride();
    await history.save(ride);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  group('Golden', () {
    goldenTest(
      'Post the loop',
      fileName: 'post_loop',
      constraints: _screen,
      pumpBeforeTest: (tester) async {
        // Decode the photo files for real, then let the screen settle.
        await tester.runAsync(() async {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          for (final element in find.byType(Image).evaluate()) {
            final image = (element.widget as Image).image;
            await precacheImage(image, element);
          }
        });
        await tester.pumpAndSettle();
      },
      builder: () {
        drafts.saved[ride.id] = PostDraft(
          rideId: ride.id,
          photos: _photos(tmp),
        ).toJson();
        return _app(history: history, drafts: drafts, ride: ride);
      },
    );
  });

  testWidgets('mockup copy, adapted for after the ride', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _app(history: history, drafts: drafts, ride: ride),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rode this loop'), findsOneWidget);
    expect(find.text('YOU MADE IT'), findsOneWidget);
    expect(find.text('Bangaan View · Viewpoint · 118 km loop'), findsOneWidget);
    expect(find.text('0 / 10'), findsOneWidget);
    expect(find.text('118 km loop · 3 h 50 ride time'), findsOneWidget);
    expect(find.text('Post later'), findsOneWidget);
    expect(find.text('Skip and keep riding'), findsNothing);

    // No photos yet: POST TO FEED is disabled.
    final post = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, 'POST TO FEED'),
    );
    expect(post.onPressed, isNull);
  });

  testWidgets('a ride too short to post says why', (tester) async {
    ride = RideSummary(
      id: newId(),
      startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      endedAt: DateTime.now().subtract(const Duration(hours: 1)),
      riddenM: 3000,
      loopM: 50000,
      reachedStop: false,
      synced: true,
    );
    await history.save(ride);
    await tester.pumpWidget(
      MaterialApp(
        home: _app(history: history, drafts: drafts, ride: ride),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Ride at least a quarter of the loop to post it.'),
      findsOneWidget,
    );
    expect(find.text('50 km loop · 1 h'), findsOneWidget);
  });

  testWidgets('picked photos are added, dated or not', (tester) async {
    final during = img.Image(width: 8, height: 8);
    final when = ride.startedAt.add(const Duration(hours: 1));
    String two(int n) => n.toString().padLeft(2, '0');
    during.exif.exifIfd[0x9003] =
        '${when.year}:${two(when.month)}:${two(when.day)} '
        '${two(when.hour)}:${two(when.minute)}:00';
    final screenshot = img.Image(width: 8, height: 8);

    await tester.pumpWidget(
      MaterialApp(
        home: _app(
          history: history,
          drafts: drafts,
          ride: ride,
          pick: ({required camera, required max}) async => [
            PickedPhoto(img.encodeJpg(during)),
            PickedPhoto(img.encodeJpg(screenshot)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Add photos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHOOSE PHOTOS'));
    // Photos are compressed on another isolate: give it real time.
    for (var i = 0; i < 50 && find.text('2 / 10').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    }
    expect(find.text('2 / 10'), findsOneWidget);
    expect(find.textContaining('Photo '), findsNothing);
  });
}
