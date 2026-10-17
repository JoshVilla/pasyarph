import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Turns any picked photo into a square JPEG avatar: fixes EXIF rotation,
/// crops the centre square, scales down to [size] px (never up) and encodes
/// at [quality]. Run it off the UI thread with `compute`.
///
/// Throws [FormatException] if the bytes aren't a supported image.
Uint8List squareAvatarJpeg(
  Uint8List bytes, {
  int size = 512,
  int quality = 85,
}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Not an image');

  final upright = img.bakeOrientation(decoded);
  final side = upright.width < upright.height ? upright.width : upright.height;
  final square = img.copyCrop(
    upright,
    x: (upright.width - side) ~/ 2,
    y: (upright.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final scaled = side > size
      ? img.copyResize(
          square,
          width: size,
          height: size,
          interpolation: img.Interpolation.average,
        )
      : square;
  return img.encodeJpg(scaled, quality: quality);
}
