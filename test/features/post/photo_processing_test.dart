import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pasyarph/features/post/photo_processing.dart';

img.Image _photo(int w, int h) {
  final image = img.Image(width: w, height: h);
  image.exif.exifIfd[0x9003] = '2026:10:18 09:00:00';
  image.exif.gpsIfd.setGpsLocation(latitude: 16.672, longitude: 121.457);
  return image;
}

void main() {
  test('at most 1600 px on the long edge, small photos untouched', () {
    final wide = processPhotoSync(img.encodeJpg(_photo(3200, 2400)))!;
    expect((wide.width, wide.height), (1600, 1200));
    final tall = processPhotoSync(img.encodeJpg(_photo(900, 2000)))!;
    expect(tall.height, 1600);
    expect(processPhotoSync(img.encodeJpg(_photo(40, 30)))!.width, 40);
  });

  test('no EXIF goes public: no date, no GPS position', () {
    final out = processPhotoSync(img.encodeJpg(_photo(64, 64)))!;
    final exif = img.decodeJpgExif(out.jpeg);
    expect(exif?.gpsIfd.gpsLatitude, isNull);
    expect(exif?.exifIfd[0x9003], isNull);
  });

  test('not an image: null', () {
    expect(
      processPhotoSync(img.encodeJpg(_photo(8, 8)).sublist(0, 20)),
      isNull,
    );
  });
}
