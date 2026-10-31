import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/repositories/post_repository.dart';
import 'package:pasyarph/features/post/photo_processing.dart';
import 'package:pasyarph/features/post/providers/post_composer.dart';
import 'package:pasyarph/features/post/providers/text_post_composer.dart';

import '../../support/fake_post.dart';

void main() {
  late Directory tmp;
  late FakePosts posts;

  TextPostComposer composer() => TextPostComposer(
    posts: posts,
    process: (bytes) async =>
        bytes.isEmpty ? null : ProcessedPhoto(bytes, 800, 600),
    photoDir: () async => tmp,
  );

  final photo = PickedPhoto(Uint8List.fromList([1, 2, 3]));

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pasyar_text_post');
    posts = FakePosts();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('POST needs words; a club post needs a club', () {
    final c = composer();
    expect(c.canPost, isFalse);
    c.setText('   ');
    expect(c.canPost, isFalse);
    c.setText('Is the road to Daranak open?');
    expect(c.canPost, isTrue);

    c.setVisibility(LoopVisibility.club);
    expect(c.canPost, isFalse);
    c.setVisibility(LoopVisibility.club, clubId: 'k1');
    expect(c.canPost, isTrue);

    // Leaving club drops the club.
    c.setVisibility(LoopVisibility.public);
    expect(c.clubId, isNull);
  });

  test('posts the trimmed words, photos in order, and who sees it', () async {
    final c = composer();
    c.setText('  Club ride Saturday, 6 AM at the plaza.  ');
    c.setVisibility(LoopVisibility.club, clubId: 'k1');
    await c.addPhotos([photo, photo]);
    expect(c.photos, hasLength(2));

    expect(await c.post(), isTrue);
    expect(posts.created.single, {
      'postId': c.postId,
      'text': 'Club ride Saturday, 6 AM at the plaza.',
      'visibility': LoopVisibility.club,
      'clubId': 'k1',
      'paths': ['user-1/${c.postId}/0.jpg', 'user-1/${c.postId}/1.jpg'],
    });
  });

  test('photos are optional', () async {
    final c = composer()..setText('Just words');
    expect(await c.post(), isTrue);
    expect(posts.created.single['paths'], isEmpty);
    expect(posts.uploads, isEmpty);
  });

  test('offline: says so without promising a draft; retry resumes', () async {
    final c = composer()..setText('Hello riders');
    await c.addPhotos([photo, photo]);
    posts.failUpload = 2;

    expect(await c.post(), isFalse);
    expect(c.error, contains("Couldn't reach Pasyar"));
    expect(c.error, isNot(contains('draft')));
    expect(posts.uploads, ['user-1/${c.postId}/0.jpg']);

    expect(await c.post(), isTrue);
    // The first photo isn't uploaded twice; the post id stays the same.
    expect(posts.uploads, [
      'user-1/${c.postId}/0.jpg',
      'user-1/${c.postId}/1.jpg',
    ]);
    expect(posts.created.single['postId'], c.postId);
  });

  test('server refusals keep their message', () async {
    posts.createErrors.add(PostException.fromServer('not_club_member'));
    final c = composer()
      ..setText('Hi')
      ..setVisibility(LoopVisibility.club, clubId: 'k1');
    expect(await c.post(), isFalse);
    expect(c.error, contains("not in that club"));
  });

  test('unreadable photos and the 10-photo limit are refused', () async {
    final c = composer();
    await c.addPhotos([PickedPhoto(Uint8List(0))]);
    expect(c.refused, ["Photo 1 couldn't be read."]);

    await c.addPhotos(List.filled(11, photo));
    expect(c.photos, hasLength(10));
    expect(c.refused, ['Photo 11: you already have 10 photos.']);
  });
}
