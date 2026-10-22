import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/models/profile.dart';
import 'package:pasyarph/data/repositories/club_repository.dart';
import 'package:pasyarph/data/repositories/feed_repository.dart';
import 'package:pasyarph/data/repositories/social_repository.dart';
import 'package:pasyarph/features/clubs/providers/club_controller.dart';
import 'package:pasyarph/features/clubs/screens/club_screen.dart';
import 'package:pasyarph/features/clubs/screens/create_club_screen.dart';
import 'package:pasyarph/features/clubs/screens/join_club_screen.dart';
import 'package:pasyarph/features/feed/providers/feed_provider.dart';
import 'package:pasyarph/features/riders/providers/rider_profile_controller.dart';
import 'package:pasyarph/features/riders/screens/rider_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../support/fake_clubs.dart';
import '../../support/fake_feed.dart';
import '../../support/fake_services.dart';
import '../../support/fake_social.dart';

final _now = DateTime(2026, 10, 19, 15);

/// Screens without a mockup (Prompt 17), built from DESIGN.md components.
/// Compare them with the feed (05) and auth screens (08, 09) they borrow
/// from.
void main() {
  late FakeClubRepository clubs;
  late FakeFeedRepository feed;
  late FakeSocialRepository social;
  late LocationProvider location;

  setUp(() async {
    clubs = FakeClubRepository()
      ..add(
        'cordon',
        'Cordon Riders',
        memberIds: ['ana', 'jun', 'rico'],
        code: '0123456789abcdef',
      )
      ..add(
        'isa',
        'Isabela Riders',
        ownerId: 'rico',
        memberIds: ['ana', 'jun'],
        code: 'fedcba9876543210',
      );
    final clubPosts = [
      feedPost(
        id: 'c1',
        createdAt: _now.subtract(const Duration(hours: 2)),
        author: 'Ana Lopez',
        loopName: 'Saturday club loop',
        province: 'Isabela',
        caption: 'Meetup at 6 AM at the plaza.',
        photos: const ['#A8B9A0', '#9FB4C4'],
        visibility: LoopVisibility.club,
        likes: 5,
        comments: 1,
      ),
    ];
    final riderPosts = [
      feedPost(
        id: 'r1',
        createdAt: _now.subtract(const Duration(days: 1)),
        author: 'Ana Lopez',
        loopName: 'Magat Dam loop',
        province: 'Isabela',
        loopOnly: true,
        curviness: 340,
      ),
    ];
    feed = FakeFeedRepository(
      const [],
      scoped: {
        const FeedScope.club('cordon'): clubPosts,
        const FeedScope.rider('ana'): riderPosts,
      },
    );
    social = FakeSocialRepository(
      riders: {
        'ana': const RiderProfile(
          id: 'ana',
          displayName: 'Ana Lopez',
          homeArea: 'Cordon, Isabela',
          bikeType: BikeType.underbone,
          followerCount: 48,
          followingCount: 12,
        ),
      },
    );
    location = LocationProvider(
      permissions: FakeLocationPermission(),
      positions: FakePositionSource(
        last: const RiderFix(point: LatLng(16.672, 121.457)),
      ),
    );
    await location.start();
  });

  Widget app(Widget screen, {List<SingleChildWidget> more = const []}) =>
      MultiProvider(
        providers: [
          Provider<ClubRepository>.value(value: clubs),
          Provider<FeedRepository>.value(value: feed),
          Provider<SocialRepository>.value(value: social),
          ChangeNotifierProvider.value(value: location),
          ...more,
        ],
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 44, bottom: 34),
              viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
            ),
            child: screen,
          ),
        ),
      );

  FeedProvider scoped(FeedScope scope) => FeedProvider(
    feed: feed,
    social: social,
    location: location,
    scope: scope,
  );

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pump();
      await tester.pump();
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  const size = BoxConstraints.tightFor(width: 390, height: 844);

  group('Golden', () {
    goldenTest(
      'Club page (owner)',
      fileName: 'club_owner',
      constraints: size,
      pumpBeforeTest: settle,
      builder: () => app(
        ClubScreen(clock: () => _now),
        more: [
          ChangeNotifierProvider(
            create: (_) => ClubController(clubs: clubs, clubId: 'cordon'),
          ),
          ChangeNotifierProvider(
            create: (_) => scoped(const FeedScope.club('cordon')),
          ),
        ],
      ),
    );
    goldenTest(
      'New club',
      fileName: 'club_new',
      constraints: size,
      builder: () => app(const CreateClubScreen()),
    );
    goldenTest(
      'Join a club',
      fileName: 'club_join',
      constraints: size,
      pumpBeforeTest: settle,
      builder: () => app(const JoinClubScreen(code: 'fedcba9876543210')),
    );
    goldenTest(
      'Rider profile',
      fileName: 'rider_profile',
      constraints: size,
      pumpBeforeTest: settle,
      builder: () => app(
        RiderProfileScreen(clock: () => _now),
        more: [
          ChangeNotifierProvider(
            create: (_) =>
                RiderProfileController(social: social, userId: 'ana'),
          ),
          ChangeNotifierProvider(
            create: (_) => scoped(const FeedScope.rider('ana')),
          ),
        ],
      ),
    );
  });
}
