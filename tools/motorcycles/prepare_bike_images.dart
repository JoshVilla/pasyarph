// Makes the bike-type card pictures from the source art in
// assets/motorcycles/*.png (white background): the white background and
// the floor shadow become transparent, the empty margin is cropped, and the
// result is scaled to card size in assets/motorcycles/cards/.
//
// Run from the project root after changing the source art:
//   dart run tools/motorcycles/prepare_bike_images.dart
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _names = ['scooter', 'underbone', 'big-bike', 'dual-sport'];

/// Background (and the pale floor shadow) is anything this light that
/// touches the edge of the picture.
const _lightMin = 200;

/// Wide enough for a 2-column card on a 3x screen.
const _outWidth = 480;

void main() {
  final out = Directory('assets/motorcycles/cards')..createSync(recursive: true);
  for (final name in _names) {
    final src = img.decodePng(
      File('assets/motorcycles/$name.png').readAsBytesSync(),
    )!;
    final cut = _cropToContent(_clearBackground(src));
    final small = img.copyResize(
      cut,
      width: math.min(_outWidth, cut.width),
      interpolation: img.Interpolation.average,
    );
    File('${out.path}/$name.png').writeAsBytesSync(img.encodePng(small));
    stdout.writeln('$name: ${small.width}x${small.height}');
  }
}

/// Flood-fills light pixels from the edges and turns them into
/// transparency ("color to alpha" against white), so soft edges and the
/// shadow keep their shape on any card color. Light parts inside the bike
/// (a headlight) aren't reached and stay.
img.Image _clearBackground(img.Image src) {
  final w = src.width;
  final h = src.height;
  final image = src.convert(numChannels: 4);
  final seen = List<bool>.filled(w * h, false);
  final queue = Queue<int>();

  bool light(int x, int y) {
    final p = image.getPixel(x, y);
    return math.min(p.r, math.min(p.g, p.b)) >= _lightMin;
  }

  void push(int x, int y) {
    final i = y * w + x;
    if (seen[i] || !light(x, y)) return;
    seen[i] = true;
    queue.add(i);
  }

  for (var x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }
  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    final x = i % w;
    final y = i ~/ w;
    if (x > 0) push(x - 1, y);
    if (x < w - 1) push(x + 1, y);
    if (y > 0) push(x, y - 1);
    if (y < h - 1) push(x, y + 1);
  }

  for (var i = 0; i < seen.length; i++) {
    if (!seen[i]) continue;
    final p = image.getPixel(i % w, i ~/ w);
    final r = p.r.toDouble();
    final g = p.g.toDouble();
    final b = p.b.toDouble();
    // How far from white: that much of the pixel is "ink" over white.
    final a = (255 - math.min(r, math.min(g, b))) / 255;
    if (a <= 0.02) {
      p
        ..r = 0
        ..g = 0
        ..b = 0
        ..a = 0;
      continue;
    }
    int ink(double c) => ((c - (1 - a) * 255) / a).round().clamp(0, 255);
    p
      ..r = ink(r)
      ..g = ink(g)
      ..b = ink(b)
      ..a = (a * 255).round();
  }
  return image;
}

/// Crops to what isn't (nearly) transparent, with a small margin.
img.Image _cropToContent(img.Image image) {
  var left = image.width;
  var top = image.height;
  var right = 0;
  var bottom = 0;
  for (final p in image) {
    if (p.a < 8) continue;
    left = math.min(left, p.x);
    right = math.max(right, p.x);
    top = math.min(top, p.y);
    bottom = math.max(bottom, p.y);
  }
  const pad = 8;
  left = math.max(0, left - pad);
  top = math.max(0, top - pad);
  right = math.min(image.width - 1, right + pad);
  bottom = math.min(image.height - 1, bottom + pad);
  return img.copyCrop(
    image,
    x: left,
    y: top,
    width: right - left + 1,
    height: bottom - top + 1,
  );
}
