import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/models/loop.dart';
import 'package:pasyarph/data/models/post.dart';
import 'package:pasyarph/data/models/profile.dart';
import 'package:pasyarph/data/repositories/feed_repository.dart';
import 'package:pasyarph/data/repositories/social_repository.dart';
import 'package:pasyarph/features/feed/feed_format.dart';
import 'package:pasyarph/features/feed/providers/feed_provider.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_services.dart';
import '../../support/fake_social.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 19, 15);

  group('format', () {
    test('time ago', () {
      expect(
        timeAgo(now.subtract(const Duration(seconds: 20)), now),
        'Just now',
      );
      expect(
        timeAgo(now.subtract(const Duration(minutes: 12)), now),
        '12 min ago',
      );
      expect(timeAgo(now.subtract(const Duration(hours: 2)), now), '2 h ago');
      expect(timeAgo(DateTime(2026, 10, 18, 23), now), 'Yesterday');
      expect(timeAgo(DateTime(2026, 10, 16, 9), now), '3 days ago');
      expect(timeAgo(DateTime(2026, 10, 4, 9), now), 'Oct 4');
      expect(timeAgo(DateTime(2025, 12, 30, 9), now), 'Dec 30, 2025');
    });

    test('distance, visibility, stop, counts', () {
      expect(distanceFromYou(6200), '6 km from you');
      expect(distanceFromYou(740), '700 m from you');
      expect(visibilityLabel(LoopVisibility.club), 'My clubs');
      expect(
        stopLabel(const MainStop(location: LatLng(0, 0), name: 'Talon')),
        'at Talon',
      );
      expect(stopLabel(const MainStop(location: LatLng(0, 0))), isNull);
      expect(plural(1, 'like'), '1 like');
      expect(plural(48, 'like'), '48 likes');
    });
  });

  group('FeedProvider', () {
    late LocationProvider location;
    late FakePositionSource gps;
    late FakeSocialRepository social;

    /// 45 posts, one every 30 minutes back from now.
    final posts = [
      for (var i = 0; i < 45; i++)
        feedPost(
          id: 'p$i',
          createdAt: now.subtract(Duration(minutes: 30 * i)),
        ),
    ];

    Future<FeedProvider> provider(
      FakeFeedRepository repo, {
      bool fix = true,
    }) async {
      social = FakeSocialRepository();
      gps = FakePositionSource(
        last: fix ? const RiderFix(point: LatLng(16.672, 121.457)) : null,
      );
      location = LocationProvider(
        permissions: FakeLocationPermission(),
        positions: gps,
      );
      await location.start();
      return FeedProvider(feed: repo, social: social, location: location);
    }

    test('first page, then the next ones by cursor until the end', () async {
      final repo = FakeFeedRepository(posts);
      final feed = await provider(repo);
      await feed.refresh();
      expect(feed.posts, hasLength(20));
      expect(feed.hasMore, isTrue);

      await feed.loadMore();
      expect(feed.posts, hasLength(40));
      expect(repo.calls[1], posts[19].createdAt);

      await feed.loadMore();
      expect(feed.posts, hasLength(45));
      expect(feed.hasMore, isFalse);
      await feed.loadMore(); // nothing left: no call
      expect(repo.calls, hasLength(3));
      expect({for (final p in feed.posts) p.id}, hasLength(45));
    });

    test('refresh starts over from the newest', () async {
      final repo = FakeFeedRepository(posts);
      final feed = await provider(repo);
      await feed.refresh();
      await feed.loadMore();
      await feed.refresh();
      expect(feed.posts, hasLength(20));
      expect(repo.calls.last, isNull);
    });

    test('offline: a message, and the posts already shown stay', () async {
      final repo = FakeFeedRepository(posts);
      final feed = await provider(repo);
      await feed.refresh();
      repo.fail = true;
      await feed.refresh();
      expect(feed.posts, hasLength(20));
      expect(feed.error, contains('pull to refresh'));
    });

    test('no location yet: waits for the first fix, then loads', () async {
      final repo = FakeFeedRepository(posts);
      final feed = await provider(repo, fix: false);
      feed.start();
      await pumpEventQueue();
      expect(feed.needsLocation, isTrue);
      expect(repo.calls, isEmpty);

      gps.emit(const RiderFix(point: LatLng(16.672, 121.457)));
      await pumpEventQueue();
      expect(feed.needsLocation, isFalse);
      expect(feed.posts, hasLength(20));
    });

    test(
      'Following and My clubs load their scope, without a location',
      () async {
        final club = [
          feedPost(id: 'c1', createdAt: now),
          feedPost(id: 'c2', createdAt: now, loopOnly: true),
        ];
        final repo = FakeFeedRepository(
          posts,
          scoped: {
            FeedScope.myClubs: club,
            FeedScope.following: [feedPost(id: 'f1', createdAt: now)],
          },
        );
        final feed = await provider(repo, fix: false);
        feed.start();
        await pumpEventQueue();
        expect(feed.needsLocation, isTrue);

        feed.setFilter(FeedFilter.myClubs);
        expect(feed.needsLocation, isFalse);
        await pumpEventQueue();
        expect(repo.scopeCalls, [FeedScope.myClubs]);
        expect([for (final p in feed.posts) p.id], ['c1', 'c2']);
        expect(feed.posts.last.isLoopOnly, isTrue);

        feed.setFilter(FeedFilter.following);
        await pumpEventQueue();
        expect([for (final p in feed.posts) p.id], ['f1']);

        // A fix arriving later doesn't reload "Near you" into this filter.
        gps.emit(const RiderFix(point: LatLng(16.672, 121.457)));
        await pumpEventQueue();
        expect(repo.calls, isEmpty);
        expect([for (final p in feed.posts) p.id], ['f1']);
      },
    );

    test('switching filters drops a page that arrives late', () async {
      final repo = _SlowFeed(posts);
      final feed = await provider(repo);
      final nearby = feed.refresh();
      feed.setFilter(FeedFilter.myClubs);
      repo.release();
      await nearby;
      await pumpEventQueue();
      expect(feed.filter, FeedFilter.myClubs);
      expect(feed.posts, isEmpty);
    });

    test('a club page or profile has a fixed scope', () async {
      final repo = FakeFeedRepository(
        posts,
        scoped: {
          const FeedScope.club('k'): [feedPost(id: 'k1', createdAt: now)],
        },
      );
      social = FakeSocialRepository();
      location = LocationProvider(
        permissions: FakeLocationPermission(),
        positions: FakePositionSource(),
      );
      final feed = FeedProvider(
        feed: repo,
        social: social,
        location: location,
        scope: const FeedScope.club('k'),
      );
      expect(feed.needsLocation, isFalse);
      await feed.refresh();
      expect([for (final p in feed.posts) p.id], ['k1']);
      expect(repo.scopeCalls, [const FeedScope.club('k')]);
    });

    test('like: flips at once, sticks when the server agrees', () async {
      final feed = await provider(FakeFeedRepository(posts));
      await feed.refresh();
      final liking = feed.toggleLike('p0');
      expect(feed.posts.first.likedByMe, isTrue); // before the server replies
      expect(feed.posts.first.likeCount, 1);
      expect(await liking, isNull);
      expect(social.likes, {'p0'});

      await feed.toggleLike('p0');
      expect(feed.posts.first.likedByMe, isFalse);
      expect(feed.posts.first.likeCount, 0);
      expect(social.calls, ['like:p0', 'unlike:p0']);
    });

    test('like: rolled back with a message when it fails', () async {
      final feed = await provider(FakeFeedRepository(posts));
      await feed.refresh();
      social.failNext = SocialException.offline;
      final error = await feed.toggleLike('p0');
      expect(error, contains("Couldn't reach Pasyar"));
      expect(feed.posts.first.likedByMe, isFalse);
      expect(feed.posts.first.likeCount, 0);
    });

    test('after the comments sheet: new count and preview', () async {
      final feed = await provider(FakeFeedRepository(posts));
      await feed.refresh();
      feed.updateComments(
        'p1',
        4,
        const FeedComment(
          author: ProfileSummary(id: 'j', displayName: 'Jun'),
          body: 'Paved?',
        ),
      );
      expect(feed.posts[1].commentCount, 4);
      expect(feed.posts[1].firstComment!.body, 'Paved?');
      feed.updateComments('p1', 0, null);
      expect(feed.posts[1].firstComment, isNull);
    });

    test('feed_near rows parse with their first comment', () {
      final post = FeedPost.fromJson({
        'id': 'p',
        'caption': null,
        'created_at': '2026-10-19T05:00:00Z',
        'stop_location': {
          'type': 'Point',
          'coordinates': [121.46, 16.70],
        },
        'distance_away_m': 6000,
        'author': {'id': 'a', 'display_name': 'Rico', 'avatar_url': null},
        'photos': [],
        'loop': {
          'id': 'l',
          'owner_id': 'a',
          'name': 'Loop',
          'source': 'generated',
          'shared_route': null,
          'distance_m': 1000,
          'duration_s': 100,
          'curviness_score': null,
          'main_stop': null,
          'visibility': 'public',
          'club_id': null,
          'created_at': '2026-10-19T05:00:00Z',
        },
        'like_count': 2,
        'comment_count': 1,
        'liked_by_me': false,
        'first_comment': {
          'body': 'Nice!',
          'author': {'id': 'b', 'display_name': 'Jun', 'avatar_url': null},
        },
      });
      expect(post.firstComment!.body, 'Nice!');
      expect(post.firstComment!.author.displayName, 'Jun');
      expect(post.isLoopOnly, isFalse);
      expect(post.distanceAwayM, 6000);
    });

    test('feed_page loop rows: a loop without a post, no distance', () {
      final item = FeedPost.fromJson({
        'kind': 'loop',
        'id': 'l',
        'caption': null,
        'created_at': '2026-10-19T05:00:00Z',
        'stop_location': {
          'type': 'Point',
          'coordinates': [121.46, 16.70],
        },
        'distance_away_m': null,
        'author': {'id': 'a', 'display_name': 'Rico', 'avatar_url': null},
        'photos': [],
        'loop': {
          'id': 'l',
          'owner_id': 'a',
          'name': 'Loop',
          'source': 'custom',
          'shared_route': null,
          'distance_m': 1000,
          'duration_s': 100,
          'curviness_score': null,
          'main_stop': null,
          'visibility': 'club',
          'club_id': 'k',
          'created_at': '2026-10-19T05:00:00Z',
        },
        'like_count': 0,
        'comment_count': 0,
        'liked_by_me': false,
        'first_comment': null,
      });
      expect(item.isLoopOnly, isTrue);
      expect(item.distanceAwayM, isNull);
      expect(item.loop.clubId, 'k');
    });
  });
}

/// "Near you" pages that wait for [release].
class _SlowFeed extends FakeFeedRepository {
  _SlowFeed(super.posts);

  final _gate = Completer<void>();
  void release() => _gate.complete();

  @override
  Future<List<FeedPost>> near(
    LatLng near, {
    DateTime? before,
    int limit = 20,
    double radiusM = feedRadiusM,
  }) async {
    await _gate.future;
    return super.near(near, before: before, limit: limit, radiusM: radiusM);
  }
}
