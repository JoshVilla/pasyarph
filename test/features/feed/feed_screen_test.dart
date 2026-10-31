import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/models/post.dart';
import 'package:pasyarph/data/repositories/feed_repository.dart';
import 'package:pasyarph/data/repositories/social_repository.dart';
import 'package:pasyarph/features/auth/providers/auth_provider.dart';
import 'package:pasyarph/features/feed/providers/feed_provider.dart';
import 'package:pasyarph/features/feed/screens/feed_screen.dart';
import 'package:pasyarph/features/feed/screens/photo_gallery_screen.dart';
import 'package:pasyarph/features/feed/widgets/post_card.dart';
import 'package:provider/provider.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_feed.dart';
import '../../support/fake_services.dart';
import '../../support/fake_social.dart';

final _now = DateTime(2026, 10, 19, 15);

/// The feed list (the filter chips scroll sideways too).
final _feedList = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

/// The feed with [posts] (and [scoped] for the other filters), already
/// loaded, as "Mark Estrada" (ME).
Future<Widget> _feed(
  List<FeedPost> posts, {
  Map<FeedScope, List<FeedPost>>? scoped,
}) async {
  final location = LocationProvider(
    permissions: FakeLocationPermission(),
    positions: FakePositionSource(
      last: const RiderFix(point: LatLng(16.672, 121.457)),
    ),
  );
  await location.start();
  final repo = FakeFeedRepository(posts, scoped: scoped);
  final social = FakeSocialRepository(comments: threadOf('p1', 3));
  final feed = FeedProvider(feed: repo, social: social, location: location);
  await feed.refresh();
  final auth = AuthProvider(
    FakeAuthRepository(
      session: fakeSession(),
      profile: fakeProfile(fullName: 'Mark Estrada'),
    ),
  );
  await pumpEventQueue();
  return MultiProvider(
    providers: [
      Provider<FeedRepository>.value(value: repo),
      Provider<SocialRepository>.value(value: social),
      ChangeNotifierProvider.value(value: location),
      ChangeNotifierProvider.value(value: feed),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 44),
          viewPadding: const EdgeInsets.only(top: 44),
        ),
        child: FeedScreen(clock: () => _now),
      ),
    ),
  );
}

/// Decodes the in-memory photos for real so goldens show them.
Future<void> _settleImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pump();
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
}

void main() {
  late Widget mockup;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockup = await _feed(mockupPosts(_now));
  });

  group('Golden', () {
    goldenTest(
      'Feed',
      fileName: 'feed',
      constraints: const BoxConstraints.tightFor(width: 390, height: 844),
      pumpBeforeTest: _settleImages,
      builder: () => mockup,
    );
    // The whole mockup (1960 px, without the 76 px tabs) to compare all
    // three cards.
    goldenTest(
      'Feed, full mockup height',
      fileName: 'feed_full',
      constraints: const BoxConstraints.tightFor(width: 390, height: 1884),
      pumpBeforeTest: _settleImages,
      builder: () => mockup,
    );
  });

  testWidgets('ride post and shared loop post', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: await tester.runAsync(() => _feed(mockupPosts(_now))) as Widget,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FEED'), findsOneWidget);
    expect(find.text('Write a post…'), findsOneWidget);
    expect(
      find.text('2 h ago · at [Stop name] Falls · Public'),
      findsOneWidget,
    );
    expect(find.text('+3'), findsOneWidget);
    expect(find.text('RIDE IT'), findsOneWidget);
    expect(find.text('118 km · 3 h 50'), findsOneWidget);
    expect(find.text('Isabela · 6 km from you'), findsOneWidget);
    expect(find.text('Liked'), findsOneWidget);
    expect(find.text('View all 12 comments'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('RIDE THIS LOOP'),
      300,
      scrollable: _feedList,
    );
    expect(find.text('5 h ago · My clubs'), findsOneWidget);
    expect(find.text('Curvy: High'), findsOneWidget);
    expect(find.text('96 km'), findsOneWidget);
    expect(find.text('Isabela'), findsOneWidget); // province chip
  });

  testWidgets('tapping a photo opens the gallery at it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: await tester.runAsync(() => _feed(mockupPosts(_now))) as Widget,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Photo 3, 3 more'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoGalleryScreen), findsOneWidget);
    expect(find.text('3 / 6'), findsOneWidget);
  });

  testWidgets('scrolling near the end loads the next page', (tester) async {
    final many = [
      for (var i = 0; i < 35; i++)
        feedPost(
          id: 'p$i',
          createdAt: _now.subtract(Duration(minutes: 30 * i)),
          caption: 'Post $i',
          photos: const ['#9FB4C4'],
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(home: await tester.runAsync(() => _feed(many)) as Widget),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Post 30'),
      2000,
      scrollable: _feedList,
      maxScrolls: 200,
    );
    expect(find.text('Post 30'), findsOneWidget);
  });

  testWidgets('My clubs: club posts, and loops shared without a post', (
    tester,
  ) async {
    final club = [
      feedPost(
        id: 'c1',
        createdAt: _now.subtract(const Duration(hours: 1)),
        caption: 'Club Sunday',
        photos: const ['#A8B9A0'],
        visibility: LoopVisibility.club,
      ),
      feedPost(
        id: 'c2',
        createdAt: _now.subtract(const Duration(hours: 3)),
        author: 'Ana Lopez',
        visibility: LoopVisibility.club,
        loopOnly: true,
        awayM: null,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home:
            await tester.runAsync(
                  () => _feed(
                    mockupPosts(_now),
                    scoped: {FeedScope.myClubs: club},
                  ),
                )
                as Widget,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My clubs'));
    await tester.pumpAndSettle();
    expect(find.text('Club Sunday'), findsOneWidget);
    expect(find.text('Isabela · 6 km from you'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('RIDE THIS LOOP'),
      300,
      scrollable: _feedList,
    );
    // The loop without a post can be ridden but not liked.
    final loopCard = find.ancestor(
      of: find.text('RIDE THIS LOOP'),
      matching: find.byType(PostCard),
    );
    expect(
      find.descendant(of: loopCard, matching: find.text('Like')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: loopCard,
        matching: find.textContaining(
          'Ana Lopez shared a new loop',
          findRichText: true,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Following and My clubs, empty: how to fill them', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: await tester.runAsync(() => _feed(mockupPosts(_now))) as Widget,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rides from riders you follow'), findsOneWidget);
    expect(find.text('RIDE IT'), findsNothing);

    await tester.tap(find.text('My clubs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Create or join a club'), findsOneWidget);
    expect(find.text('MY CLUBS'), findsOneWidget);
  });

  testWidgets('a text post: the rider, their words, no loop', (tester) async {
    final text = feedPost(
      id: 't1',
      createdAt: _now.subtract(const Duration(hours: 2)),
      author: 'Ana Lopez',
      caption: 'Is the road to Daranak open?',
      text: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home:
            await tester.runAsync(
                  () => _feed(
                    mockupPosts(_now),
                    scoped: {
                      FeedScope.global: [text],
                    },
                  ),
                )
                as Widget,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Global'));
    await tester.pumpAndSettle();

    final card = find.byType(PostCard);
    expect(card, findsOneWidget);
    expect(find.text('Is the road to Daranak open?'), findsOneWidget);
    expect(find.text('2 h ago · Public'), findsOneWidget);
    expect(find.textContaining(' rode ', findRichText: true), findsNothing);
    expect(find.text('RIDE IT'), findsNothing);
    expect(find.text('RIDE THIS LOOP'), findsNothing);
    expect(find.text('Comment'), findsOneWidget);
  });

  testWidgets('no posts anywhere: GENERATE A LOOP', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: await tester.runAsync(() => _feed(const [])) as Widget),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No rides on Pasyar yet'), findsOneWidget);
    expect(find.text('GENERATE A LOOP'), findsOneWidget);
    expect(find.text('No rides near you yet'), findsNothing);
  });

  testWidgets('no posts nearby: Global posts under a note', (tester) async {
    final elsewhere = [
      feedPost(
        id: 'g1',
        createdAt: _now.subtract(const Duration(hours: 2)),
        caption: 'Up north',
        photos: const ['#9FB4C4'],
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home:
            await tester.runAsync(
                  () => _feed(const [], scoped: {FeedScope.global: elsewhere}),
                )
                as Widget,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No rides near you yet'), findsOneWidget);
    expect(find.text('Up north'), findsOneWidget);
    expect(find.text('GENERATE A LOOP'), findsNothing);
  });
}
