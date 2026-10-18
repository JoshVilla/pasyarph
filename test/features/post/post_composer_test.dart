import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/data/ids.dart';
import 'package:pasyarph/data/repositories/post_repository.dart';
import 'package:pasyarph/data/repositories/ride_history_repository.dart';
import 'package:pasyarph/features/post/photo_processing.dart';
import 'package:pasyarph/features/post/providers/post_composer.dart';

import '../../support/fake_post.dart';
import '../../support/fake_services.dart';

/// A JPEG whose EXIF says it was taken at [taken] (camera format).
PickedPhoto _photo(String? taken) {
  final image = img.Image(width: 8, height: 8);
  if (taken != null) image.exif.exifIfd[0x9003] = taken;
  return PickedPhoto(img.encodeJpg(image));
}

final _during = _photo('2026:10:18 09:30:00');

void main() {
  late Directory tmp;
  late FakeRideHistory history;
  late FakePosts posts;
  late MemoryDrafts drafts;
  late RideSummary ride;

  RideSummary makeRide({double ridden = 40000}) => RideSummary(
    id: newId(),
    startedAt: DateTime(2026, 10, 18, 8),
    endedAt: DateTime(2026, 10, 18, 11),
    riddenM: ridden,
    loopM: 50000,
    loopDurationS: 3 * 3600,
    stop: const RideStop(
      location: LatLng(16.70, 121.46),
      type: 'waterfall',
      name: 'Talon',
    ),
    reachedStop: true,
    preview: const [LatLng(16.672, 121.457), LatLng(16.70, 121.46)],
    synced: true,
  );

  PostComposer composer() => PostComposer(
    rideId: ride.id,
    history: history,
    posts: posts,
    drafts: drafts,
    process: (bytes) async => ProcessedPhoto(bytes, 1600, 1200),
    clock: () => DateTime(2026, 10, 19, 9),
  );

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('pasyar_post');
    history = FakeRideHistory();
    posts = FakePosts();
    drafts = MemoryDrafts(tmp);
    ride = makeRide();
    await history.save(ride);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('opens the ride; posting needs a photo', () async {
    final c = composer();
    await c.load();
    expect(c.phase, ComposerPhase.editing);
    expect(c.blockedReason, isNull);
    expect(c.canPost, isFalse);
    expect(c.stop!.typeLabel, 'Waterfall');
  });

  test('any photo is kept, whatever its date; only 10 fit', () async {
    final c = composer();
    await c.load();
    await c.addPhotos([_during, _photo('2026:01:01 09:30:00'), _photo(null)]);
    expect(c.photos, hasLength(3));
    expect(File(c.photos.first.path).existsSync(), isTrue);
    expect(c.refused, isEmpty);
    expect(c.canPost, isTrue);

    await c.addPhotos(List.filled(9, _during));
    expect(c.photos, hasLength(10));
    expect(c.refused, hasLength(2));
    expect(c.refused.first, contains('already have 10'));
  });

  test(
    'post: photos under the post folder, then the post; ride marked',
    () async {
      final c = composer();
      await c.load();
      await c.addPhotos([_during, _during]);
      c.setCaption('Ganda ng falls!');
      expect(await c.post(), isTrue);

      final postId = posts.created.single['postId'];
      expect(posts.uploads, ['user-1/$postId/0.jpg', 'user-1/$postId/1.jpg']);
      expect(posts.created.single['loopName'], 'Talon loop');
      expect(posts.created.single['caption'], 'Ganda ng falls!');
      expect(c.phase, ComposerPhase.posted);
      expect((await history.byId(ride.id))!.posted, isTrue);
      expect(drafts.saved, isEmpty);
    },
  );

  test(
    'a failed upload keeps the draft; the retry skips done photos',
    () async {
      final c = composer();
      await c.load();
      await c.addPhotos([_during, _during, _during]);
      posts.failUpload = 2;
      expect(await c.post(), isFalse);
      expect(c.error, contains('draft is saved'));
      expect(c.phase, ComposerPhase.editing);
      expect(posts.uploads, hasLength(1));

      expect(await c.post(), isTrue);
      expect(posts.uploads, hasLength(3)); // 0 once, then 1 and 2
      expect(posts.uploads.toSet(), hasLength(3));
    },
  );

  test('lost reply: "already posted" on the retry counts as posted', () async {
    final c = composer();
    await c.load();
    await c.addPhotos([_during]);
    posts.createErrors.add(PostException.offline);
    expect(await c.post(), isFalse);

    posts.createErrors.add(PostException.fromServer('ride_already_posted'));
    expect(await c.post(), isTrue);
    expect(c.phase, ComposerPhase.posted);
  });

  test('a ride ridden less than a quarter of the loop is blocked', () async {
    ride = makeRide(ridden: 9000);
    await history.save(ride);
    final c = composer();
    await c.load();
    await c.addPhotos([_during]);
    expect(c.blockedReason, contains('quarter'));
    expect(c.canPost, isFalse);
  });

  test('the draft survives a restart', () async {
    final first = composer();
    await first.load();
    await first.addPhotos([_during]);
    first.setCaption('Sunrise');
    first.dispose();

    final again = composer();
    await again.load();
    expect(again.photos, hasLength(1));
    expect(again.caption, 'Sunrise');
  });

  test('removing a photo re-uploads the ones after it', () async {
    final c = composer();
    await c.load();
    await c.addPhotos([_during, _during, _during]);
    posts.failUpload = 3;
    await c.post(); // 0 and 1 uploaded
    await c.removePhoto(0);
    expect(c.photos.map((p) => p.uploaded), [false, false]);
    expect(await c.post(), isTrue);
  });
}
