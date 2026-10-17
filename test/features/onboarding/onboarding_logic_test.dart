import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pasyarph/features/onboarding/avatar_image.dart';
import 'package:pasyarph/features/onboarding/onboarding_rules.dart';

void main() {
  group('squareAvatarJpeg', () {
    test('crops the centre square and scales down to 512', () {
      // 1200 × 800: left third red, middle blue, right third red.
      final src = img.Image(width: 1200, height: 800);
      img.fill(src, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(
        src,
        x1: 200,
        y1: 0,
        x2: 999,
        y2: 799,
        color: img.ColorRgb8(0, 0, 255),
      );
      final out = img.decodeJpg(squareAvatarJpeg(img.encodePng(src)))!;

      expect(out.width, 512);
      expect(out.height, 512);
      // The centre square (x 200-999) is all blue, so even the edges are.
      final edge = out.getPixel(2, 256);
      expect(edge.b, greaterThan(200));
      expect(edge.r, lessThan(60));
    });

    test('does not scale small photos up', () {
      final src = img.Image(width: 300, height: 400);
      final out = img.decodeJpg(squareAvatarJpeg(img.encodePng(src)))!;
      expect((out.width, out.height), (300, 300));
    });

    test('rejects non-images', () {
      expect(
        () => squareAvatarJpeg(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('OnboardingRules', () {
    test('rider name is 2-30 characters', () {
      expect(OnboardingRules.riderName(' J '), isNotNull);
      expect(OnboardingRules.riderName('Juan'), isNull);
      expect(OnboardingRules.riderName('x' * 31), isNotNull);
    });

    test('home area is optional, town only', () {
      expect(OnboardingRules.homeArea(''), isNull);
      expect(OnboardingRules.homeArea('Cordon, Isabela'), isNull);
      expect(OnboardingRules.homeArea('123 Rizal St, Cordon'), isNotNull);
    });

    test('suggests the first name', () {
      expect(OnboardingRules.suggestRiderName('Juan Dela Cruz'), 'Juan');
      expect(OnboardingRules.suggestRiderName(null), '');
      expect(OnboardingRules.suggestRiderName('  Ana  '), 'Ana');
    });
  });
}
