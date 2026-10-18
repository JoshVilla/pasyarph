import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/data/repositories/feed_repository.dart';
import 'package:pasyarph/data/repositories/social_repository.dart';
import 'package:pasyarph/features/feed/providers/comments_controller.dart';
import 'package:pasyarph/features/feed/widgets/comments_sheet.dart';
import 'package:provider/provider.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_services.dart';
import '../../support/fake_social.dart';

final _now = DateTime.utc(2026, 10, 19, 7);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommentsController', () {
    test('loads oldest first, then pages by cursor', () async {
      final social = FakeSocialRepository(comments: threadOf('p', 45));
      final c = CommentsController(
        postId: 'p',
        social: social,
        count: 45,
        pageSize: 20,
      );
      await c.load();
      expect(c.comments.first.body, 'Comment 0');
      expect(c.comments, hasLength(20));
      expect(c.firstComment!.body, 'Comment 0');

      await c.loadMore();
      await c.loadMore();
      expect(c.comments, hasLength(45));
      expect(c.hasMore, isFalse);
      expect(c.comments.map((x) => x.id).toSet(), hasLength(45));
    });

    test(
      'send: shows at the end and counts, even before the last page',
      () async {
        final social = FakeSocialRepository(comments: threadOf('p', 25));
        final c = CommentsController(
          postId: 'p',
          social: social,
          count: 25,
          pageSize: 20,
        );
        await c.load();
        expect(await c.send('  Paved all the way?  '), isTrue);
        expect(c.count, 26);
        expect(c.comments.last.body, 'Paved all the way?');
        expect(social.calls, contains('add:Paved all the way?'));

        // Paging in the rest doesn't duplicate it.
        await c.loadMore();
        expect(
          c.comments.where((x) => x.body == 'Paved all the way?'),
          hasLength(1),
        );
        expect(c.comments, hasLength(26));

        expect(await c.send('   '), isFalse); // blank: nothing sent
      },
    );

    test('refused comments keep the text and say why', () async {
      final social = FakeSocialRepository();
      final c = CommentsController(postId: 'p', social: social, count: 0);
      await c.load();
      social.failNext = SocialException.blocked;
      expect(await c.send('tangina'), isFalse);
      expect(c.error, contains('keep it friendly'));
      expect(c.count, 0);

      social.failNext = SocialException.duplicate;
      expect(await c.send('Nice!'), isFalse);
      expect(c.error, 'You already posted that comment.');
    });

    test('delete own: gone at once, back if it fails; not others\'', () async {
      final social = FakeSocialRepository(comments: threadOf('p', 4));
      final c = CommentsController(postId: 'p', social: social, count: 4);
      await c.load();
      final mine = c.comments[1];
      final theirs = c.comments[0];
      expect(c.isMine(mine), isTrue);
      expect(c.isMine(theirs), isFalse);

      social.failNext = SocialException.offline;
      await c.delete(mine);
      expect(c.comments, contains(mine));
      expect(c.count, 4);

      await c.delete(mine);
      expect(c.comments, isNot(contains(mine)));
      expect(c.count, 3);

      await c.delete(theirs);
      expect(c.comments, contains(theirs));
    });
  });

  group('CommentsSheet', () {
    Future<Widget> sheet(CommentsController c) async {
      final location = LocationProvider(
        permissions: FakeLocationPermission(),
        positions: FakePositionSource(
          last: const RiderFix(point: LatLng(16.672, 121.457)),
        ),
      );
      await location.start();
      return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: location),
          Provider<FeedRepository>.value(value: FakeFeedRepository(const [])),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF8A8D93),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CommentsSheet(controller: c, clock: () => _now),
            ),
          ),
        ),
      );
    }

    late CommentsController controller;
    late Widget app;
    setUpAll(() async {
      final social = FakeSocialRepository(comments: threadOf('p', 4));
      controller = CommentsController(postId: 'p', social: social, count: 4);
      await controller.load();
      app = await sheet(controller);
    });

    goldenTest(
      'Comments',
      fileName: 'comments_sheet',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      builder: () => app,
    );

    testWidgets('lists comments; Delete only on your own; send posts', (
      tester,
    ) async {
      final social = FakeSocialRepository(comments: threadOf('p', 4));
      final c = CommentsController(postId: 'p', social: social, count: 4);
      await tester.runAsync(c.load);
      await tester.pumpWidget(await tester.runAsync(() => sheet(c)) as Widget);
      await tester.pumpAndSettle();
      expect(find.text('COMMENTS'), findsOneWidget);
      expect(find.text('4 comments'), findsOneWidget);
      expect(find.text('Delete'), findsNWidgets(2)); // comments 1 and 3

      await tester.enterText(find.byType(TextField), 'Ganda ng falls!');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send comment'));
      await tester.pumpAndSettle();
      expect(find.text('5 comments'), findsOneWidget);
      expect(find.textContaining('Ganda ng falls!'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('no comments yet: a prompt to start', (tester) async {
      final c = CommentsController(
        postId: 'p',
        social: FakeSocialRepository(),
        count: 0,
      );
      await tester.runAsync(c.load);
      await tester.pumpWidget(await tester.runAsync(() => sheet(c)) as Widget);
      await tester.pumpAndSettle();
      expect(find.textContaining('No comments yet'), findsOneWidget);
    });
  });
}
