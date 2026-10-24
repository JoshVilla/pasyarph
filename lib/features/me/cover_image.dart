import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:image/image.dart' as img;

/// The cover banner's shape: 390 wide by 150 tall on a 390 pt phone.
const coverAspect = 390 / 150;

/// Saved covers are at most this wide.
const coverMaxWidth = 1500;

/// A picked photo ready for the crop screen: upright (EXIF applied) and at
/// most [maxSide] px, re-encoded so what's shown is exactly what's cropped.
class CoverSource {
  const CoverSource(this.bytes, this.width, this.height);

  final Uint8List bytes;
  final int width;
  final int height;
}

/// Run with `compute`. Throws [FormatException] when it isn't an image.
CoverSource prepareCoverSource(Uint8List bytes, {int maxSide = 2400}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Not an image');
  var upright = img.bakeOrientation(decoded);
  final side = upright.width > upright.height ? upright.width : upright.height;
  if (side > maxSide) {
    upright = upright.width >= upright.height
        ? img.copyResize(upright, width: maxSide)
        : img.copyResize(upright, height: maxSide);
  }
  return CoverSource(
    img.encodeJpg(upright, quality: 92),
    upright.width,
    upright.height,
  );
}

/// The part of an image of [imageWidth] × [imageHeight] that fills a crop
/// frame of [frameWidth] × [frameHeight], when the image is drawn to cover
/// the frame (BoxFit.cover), then zoomed by [scale] and moved by
/// [dx], [dy] (the InteractiveViewer transform). In image pixels, kept
/// inside the image.
Rect coverCropRect({
  required double imageWidth,
  required double imageHeight,
  required double frameWidth,
  required double frameHeight,
  double scale = 1,
  double dx = 0,
  double dy = 0,
}) {
  final base = [
    frameWidth / imageWidth,
    frameHeight / imageHeight,
  ].reduce((a, b) => a > b ? a : b);
  final px = base * scale; // screen points per image pixel
  final w = (frameWidth / px).clamp(1.0, imageWidth);
  final h = (frameHeight / px).clamp(1.0, imageHeight);
  final left = (-dx / px).clamp(0.0, imageWidth - w);
  final top = (-dy / px).clamp(0.0, imageHeight - h);
  return Rect.fromLTWH(left, top, w, h);
}

/// Crops [source] to [rect] (image pixels), scales it down to
/// [coverMaxWidth] and encodes a JPEG. Run with `compute`.
Uint8List cropCoverJpeg((Uint8List, Rect) args, {int quality = 80}) {
  final (bytes, rect) = args;
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Not an image');
  var out = img.copyCrop(
    image,
    x: rect.left.round(),
    y: rect.top.round(),
    width: rect.width.round(),
    height: rect.height.round(),
  );
  if (out.width > coverMaxWidth) {
    out = img.copyResize(
      out,
      width: coverMaxWidth,
      height: (coverMaxWidth / coverAspect).round(),
      interpolation: img.Interpolation.average,
    );
  }
  return img.encodeJpg(out, quality: quality);
}
