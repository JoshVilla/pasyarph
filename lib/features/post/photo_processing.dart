import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A photo ready to upload.
class ProcessedPhoto {
  const ProcessedPhoto(this.jpeg, this.width, this.height);

  final Uint8List jpeg;
  final int width;
  final int height;
}

/// Longest edge after resizing, and JPEG quality.
const photoMaxEdge = 1600;
const photoQuality = 80;

/// Upright, at most [photoMaxEdge] px, re-encoded as JPEG without EXIF (no
/// GPS position goes public). Null when the image can't be decoded. Runs
/// off the UI thread.
Future<ProcessedPhoto?> processPhoto(Uint8List bytes) =>
    compute(processPhotoSync, bytes);

@visibleForTesting
ProcessedPhoto? processPhotoSync(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var out = img.bakeOrientation(decoded);
  final longest = out.width > out.height ? out.width : out.height;
  if (longest > photoMaxEdge) {
    out = out.width >= out.height
        ? img.copyResize(out, width: photoMaxEdge)
        : img.copyResize(out, height: photoMaxEdge);
  }
  out.exif = img.ExifData();
  return ProcessedPhoto(
    img.encodeJpg(out, quality: photoQuality),
    out.width,
    out.height,
  );
}
