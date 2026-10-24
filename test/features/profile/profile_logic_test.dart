import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pasyarph/data/models/enums.dart';
import 'package:pasyarph/data/repositories/cover_repository.dart';
import 'package:pasyarph/features/me/cover_image.dart';
import 'package:pasyarph/features/me/profile_rules.dart';

void main() {
  group('usernames', () {
    test('saved trimmed, lowercase, without the @', () {
      expect(normalizeUsername('  @Ana.Rides_1 '), 'ana.rides_1');
    });

    test('3-20 letters, numbers, dots and underscores', () {
      expect(usernameError('ana.rides'), isNull);
      expect(usernameError('@Ana_1'), isNull);
      expect(usernameError(''), 'Pick a username so riders can find you.');
      expect(usernameError('ab'), 'At least 3 characters.');
      expect(usernameError('a' * 21), 'At most 20 characters.');
      expect(
        usernameError('ana rides'),
        'Use letters, numbers, dots and underscores only.',
      );
      expect(usernameError('ana-rides'), isNotNull);
    });

    test('bios up to 150 characters', () {
      expect(bioError('x' * 150), isNull);
      expect(bioError('x' * 151), 'At most 150 characters.');
    });
  });

  test('handle line leaves out what is missing', () {
    expect(
      handleLine(
        username: 'ana',
        bike: BikeType.bigBike,
        homeArea: 'Cordon, Isabela',
      ),
      '@ana · Big bike · Cordon, Isabela',
    );
    expect(handleLine(bike: BikeType.scooter), 'Scooter');
    expect(handleLine(), '');
  });

  group('cover crop', () {
    // A 3000 × 2000 photo in a 358 × 137.6 frame (390:150).
    const frameW = 358.0;
    const frameH = frameW / coverAspect;

    test('unmoved: the top band at full width', () {
      final r = coverCropRect(
        imageWidth: 3000,
        imageHeight: 2000,
        frameWidth: frameW,
        frameHeight: frameH,
      );
      expect(r.left, 0);
      expect(r.top, 0);
      expect(r.width, closeTo(3000, 0.01));
      expect(r.width / r.height, closeTo(coverAspect, 0.01));
    });

    test('zoomed 2× and moved: the part in the frame', () {
      final base = frameW / 3000;
      final r = coverCropRect(
        imageWidth: 3000,
        imageHeight: 2000,
        frameWidth: frameW,
        frameHeight: frameH,
        scale: 2,
        dx: -frameW / 2,
        dy: -100,
      );
      expect(r.width, closeTo(1500, 0.01));
      expect(r.left, closeTo(750, 0.01));
      expect(r.top, closeTo(100 / (base * 2), 0.01));
    });

    test('never outside the photo', () {
      final r = coverCropRect(
        imageWidth: 1000,
        imageHeight: 1000,
        frameWidth: frameW,
        frameHeight: frameH,
        dx: 5000,
        dy: -99999,
      );
      expect(r.left, 0);
      expect(r.bottom, lessThanOrEqualTo(1000));
    });

    test('saved at most 1500 px wide, banner shaped, as a JPEG', () {
      final src = img.encodeJpg(img.Image(width: 3000, height: 2000));
      final out = img.decodeJpg(
        cropCoverJpeg((
          src,
          const Rect.fromLTWH(0, 0, 3000, 3000 / coverAspect),
        )),
      )!;
      expect(out.width, coverMaxWidth);
      expect(out.width / out.height, closeTo(coverAspect, 0.01));
    });

    test('photos are made upright and at most 2400 px for cropping', () {
      final src = img.encodeJpg(img.Image(width: 4000, height: 1000));
      final prepared = prepareCoverSource(src);
      expect(prepared.width, 2400);
      expect(prepared.height, 600);
      expect(() => prepareCoverSource(Uint8List(3)), throwsFormatException);
    });
  });

  test('a cover URL gives its path in the bucket', () {
    expect(
      coverPathFromUrl(
        'https://x.supabase.co/storage/v1/object/public/covers/u1/cover_1.jpg?v=2',
      ),
      'u1/cover_1.jpg',
    );
    expect(coverPathFromUrl('https://example.com/a.jpg'), isNull);
  });
}
