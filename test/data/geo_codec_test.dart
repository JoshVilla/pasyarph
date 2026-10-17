import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/data/geo/geo_codec.dart';

/// Builds hex WKB the way PostGIS does, for round-trip checks.
String wkbHex({
  required int type,
  required List<List<double>> coords,
  int? srid,
  Endian endian = Endian.little,
  bool z = false,
}) {
  final b = BytesBuilder();
  final word = ByteData(8);
  void u8(int v) => b.addByte(v);
  void u32(int v) {
    word.setUint32(0, v, endian);
    b.add(word.buffer.asUint8List(0, 4));
  }

  void f64(double v) {
    word.setFloat64(0, v, endian);
    b.add(word.buffer.asUint8List(0, 8));
  }

  u8(endian == Endian.little ? 1 : 0);
  u32(type | (srid != null ? 0x20000000 : 0) | (z ? 0x80000000 : 0));
  if (srid != null) u32(srid);
  if (type == 2) u32(coords.length);
  for (final c in coords) {
    c.forEach(f64);
  }
  return b
      .toBytes()
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
}

void main() {
  group('GeoCodec.parsePoint', () {
    test('reads EWKB with SRID (what PostgREST returns)', () {
      final hex = wkbHex(
        type: 1,
        srid: 4326,
        coords: [
          [121.47, 16.69],
        ],
      );
      expect(GeoCodec.parsePoint(hex), const LatLng(16.69, 121.47));
    });

    test('reads a real PostGIS value', () {
      // select 'SRID=4326;POINT(121.47 16.69)'::geography
      const hex = '0101000020E6100000AE47E17A145E5E40713D0AD7A3B03040';
      final p = GeoCodec.parsePoint(hex);
      expect(p.latitude, closeTo(16.69, 1e-9));
      expect(p.longitude, closeTo(121.47, 1e-9));
    });

    test('reads big-endian WKB and skips Z', () {
      final hex = wkbHex(
        type: 1,
        coords: [
          [121.0, 16.0, 120.0],
        ],
        endian: Endian.big,
        z: true,
      );
      expect(GeoCodec.parsePoint(hex), const LatLng(16, 121));
    });

    test('reads GeoJSON', () {
      expect(
        GeoCodec.parsePoint({
          'type': 'Point',
          'coordinates': [121.47, 16.69],
        }),
        const LatLng(16.69, 121.47),
      );
    });

    test('rejects a LineString', () {
      final hex = wkbHex(
        type: 2,
        coords: [
          [1, 2],
          [3, 4],
        ],
      );
      expect(() => GeoCodec.parsePoint(hex), throwsFormatException);
    });
  });

  group('GeoCodec.parseLineString', () {
    test('reads EWKB', () {
      final hex = wkbHex(
        type: 2,
        srid: 4326,
        coords: [
          [121.45, 16.67],
          [121.47, 16.69],
          [121.49, 16.67],
        ],
      );
      expect(GeoCodec.parseLineString(hex), const [
        LatLng(16.67, 121.45),
        LatLng(16.69, 121.47),
        LatLng(16.67, 121.49),
      ]);
    });

    test('reads GeoJSON (RPC results)', () {
      expect(
        GeoCodec.parseLineString({
          'type': 'LineString',
          'coordinates': [
            [121.45, 16.67],
            [121.47, 16.69],
          ],
        }),
        const [LatLng(16.67, 121.45), LatLng(16.69, 121.47)],
      );
    });

    test('null passes through the OrNull variant', () {
      expect(GeoCodec.parseLineStringOrNull(null), isNull);
    });

    test('rejects bad input', () {
      expect(() => GeoCodec.parseLineString('zz'), throwsFormatException);
      expect(() => GeoCodec.parseLineString(42), throwsFormatException);
    });
  });

  group('GeoCodec EWKT output', () {
    test('writes lng lat order with SRID', () {
      expect(
        GeoCodec.lineStringToEwkt(const [
          LatLng(16.67, 121.45),
          LatLng(16.69, 121.47),
        ]),
        'SRID=4326;LINESTRING(121.45 16.67,121.47 16.69)',
      );
      expect(
        GeoCodec.pointToEwkt(const LatLng(16.69, 121.47)),
        'SRID=4326;POINT(121.47 16.69)',
      );
    });

    test('a line needs two points', () {
      expect(
        () => GeoCodec.lineStringToEwkt(const [LatLng(1, 2)]),
        throwsArgumentError,
      );
    });
  });
}
