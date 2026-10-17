import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/data/models/models.dart';

void main() {
  test('Profile parses a row', () {
    final p = Profile.fromJson({
      'id': 'u1',
      'full_name': 'Juan Dela Cruz',
      'display_name': 'Juan',
      'avatar_url': null,
      'bike_type': 'big_bike',
      'home_area': 'Cordon, Isabela',
      'onboarding_completed': true,
      'terms_accepted_at': '2026-10-18T01:02:03+00:00',
      'created_at': '2026-10-18T01:00:00+00:00',
    });
    expect(p.bikeType, BikeType.bigBike);
    expect(p.onboardingCompleted, isTrue);
    expect(p.toUpdateJson()['bike_type'], 'big_bike');
  });

  test('Loop parses a row with EWKB shared_route and main_stop', () {
    final loop = Loop.fromJson({
      'id': 'l1',
      'owner_id': 'u1',
      'name': 'Sunday Falls Loop',
      'source': 'custom',
      // select 'SRID=4326;LINESTRING(121.45 16.66,121.47 16.69)'::geography
      'shared_route':
          '0102000020E610000002000000CDCCCCCCCC5C5E40295C8FC2F5A83040AE47E17A14'
          '5E5E40713D0AD7A3B03040',
      'distance_m': 96000,
      'duration_s': 11400,
      'curviness_score': 4.5,
      'main_stop': {
        'name': 'Falls',
        'type': 'waterfall',
        'lat': 16.69,
        'lng': 121.47,
      },
      'visibility': 'club',
      'club_id': 'c1',
      'created_at': '2026-10-18T01:00:00Z',
    });
    expect(loop.source, LoopSource.custom);
    expect(loop.visibility, LoopVisibility.club);
    expect(loop.sharedRoute, hasLength(2));
    expect(loop.sharedRoute!.first.latitude, closeTo(16.66, 1e-9));
    expect(loop.mainStop!.location, const LatLng(16.69, 121.47));
  });

  test('Loop allows a null shared_route (not trimmed yet)', () {
    final loop = Loop.fromJson({
      'id': 'l1',
      'owner_id': 'u1',
      'name': 'x',
      'source': 'generated',
      'shared_route': null,
      'distance_m': 1,
      'duration_s': 1,
      'curviness_score': null,
      'main_stop': null,
      'visibility': 'public',
      'club_id': null,
      'created_at': '2026-10-18T01:00:00Z',
    });
    expect(loop.sharedRoute, isNull);
    expect(Loop.columns.split(','), isNot(contains('route')));
  });

  test('NewLoop writes EWKT and enum values', () {
    final json = const NewLoop(
      name: 'Quick loop',
      source: LoopSource.generated,
      route: [LatLng(16.67, 121.45), LatLng(16.69, 121.47)],
      distanceM: 54000,
      durationS: 4200,
    ).toJson();
    expect(json['route'], 'SRID=4326;LINESTRING(121.45 16.67,121.47 16.69)');
    expect(json['visibility'], 'public');
    expect(json.containsKey('owner_id'), isFalse);
  });

  test('FeedPost parses a feed_near row', () {
    final post = FeedPost.fromJson({
      'id': 'p1',
      'caption': 'Falls were full',
      'created_at': '2026-10-18T01:00:00Z',
      'stop_location': {
        'type': 'Point',
        'coordinates': [121.47, 16.69],
      },
      'distance_away_m': 1234.5,
      'author': {'id': 'u1', 'display_name': 'Ana', 'avatar_url': null},
      'photos': [
        {
          'id': 'ph1',
          'post_id': 'p1',
          'storage_path': 'u1/p1/0.jpg',
          'position': 0,
          'width': 1600,
          'height': 1200,
        },
      ],
      'loop': {
        'id': 'l1',
        'owner_id': 'u1',
        'name': 'Public loop',
        'source': 'generated',
        'shared_route': {
          'type': 'LineString',
          'coordinates': [
            [121.46, 16.68],
            [121.47, 16.69],
          ],
        },
        'distance_m': 9000,
        'duration_s': 900,
        'curviness_score': null,
        'main_stop': null,
        'visibility': 'public',
        'club_id': null,
        'created_at': '2026-10-18T00:00:00Z',
      },
      'like_count': 1,
      'comment_count': 2,
      'liked_by_me': true,
    });
    expect(post.author.displayName, 'Ana');
    expect(post.photos.single.storagePath, 'u1/p1/0.jpg');
    expect(post.loop.sharedRoute, hasLength(2));
    expect(post.likedByMe, isTrue);
  });

  test('enums reject unknown values', () {
    expect(() => BikeType.fromValue('tricycle'), throwsFormatException);
  });
}
