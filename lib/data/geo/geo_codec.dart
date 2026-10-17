import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

/// Converts PostGIS geography values to and from [LatLng].
///
/// Reading: table columns arrive from the Supabase API as hex EWKB strings
/// (e.g. `0102000020E6100000...`); the RPCs return GeoJSON maps. Both are
/// accepted. Writing: PostGIS accepts EWKT, e.g.
/// `SRID=4326;LINESTRING(121.45 16.67,121.46 16.68)`.
abstract final class GeoCodec {
  static const _srid = 4326;

  static LatLng parsePoint(Object value) {
    final points = _parse(value, expectedType: _pointType);
    return points.single;
  }

  static List<LatLng> parseLineString(Object value) =>
      _parse(value, expectedType: _lineStringType);

  static LatLng? parsePointOrNull(Object? value) =>
      value == null ? null : parsePoint(value);

  static List<LatLng>? parseLineStringOrNull(Object? value) =>
      value == null ? null : parseLineString(value);

  static String pointToEwkt(LatLng point) =>
      'SRID=$_srid;POINT(${_coord(point)})';

  static String lineStringToEwkt(List<LatLng> points) {
    if (points.length < 2) {
      throw ArgumentError.value(points, 'points', 'needs at least 2 points');
    }
    return 'SRID=$_srid;LINESTRING(${points.map(_coord).join(',')})';
  }

  static String _coord(LatLng p) => '${p.longitude} ${p.latitude}';

  static const _pointType = 1;
  static const _lineStringType = 2;

  static List<LatLng> _parse(Object value, {required int expectedType}) {
    return switch (value) {
      final String hex => _parseWkbHex(hex, expectedType),
      final Map<String, dynamic> json => _parseGeoJson(json, expectedType),
      _ => throw FormatException('Unsupported geometry value: $value'),
    };
  }

  static List<LatLng> _parseGeoJson(Map<String, dynamic> json, int expected) {
    final type = json['type'];
    final coords = json['coordinates'];
    LatLng toLatLng(Object? c) {
      final xy = c! as List;
      return LatLng((xy[1] as num).toDouble(), (xy[0] as num).toDouble());
    }

    if (expected == _pointType && type == 'Point') return [toLatLng(coords)];
    if (expected == _lineStringType && type == 'LineString') {
      return [for (final c in coords as List) toLatLng(c)];
    }
    throw FormatException('Expected ${_name(expected)}, got $type');
  }

  static List<LatLng> _parseWkbHex(String hex, int expected) {
    if (hex.length.isOdd || hex.length < 10) {
      throw FormatException('Invalid WKB hex', hex);
    }
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    final data = ByteData.sublistView(bytes);
    final endian = switch (data.getUint8(0)) {
      0 => Endian.big,
      1 => Endian.little,
      _ => throw FormatException('Invalid WKB byte order', hex),
    };
    var offset = 1;
    int readUint32() {
      final v = data.getUint32(offset, endian);
      offset += 4;
      return v;
    }

    double readDouble() {
      final v = data.getFloat64(offset, endian);
      offset += 8;
      return v;
    }

    final rawType = readUint32();
    // EWKB flags (PostGIS) and ISO WKB type codes (1001, 2002, ...).
    var hasZ = rawType & 0x80000000 != 0;
    var hasM = rawType & 0x40000000 != 0;
    final hasSrid = rawType & 0x20000000 != 0;
    final isoType = rawType & 0x0FFFFFFF;
    final baseType = isoType % 1000;
    switch (isoType ~/ 1000) {
      case 1:
        hasZ = true;
      case 2:
        hasM = true;
      case 3:
        hasZ = true;
        hasM = true;
    }
    if (hasSrid) readUint32();

    if (baseType != expected) {
      throw FormatException(
        'Expected ${_name(expected)}, got WKB type $baseType',
      );
    }

    LatLng readPoint() {
      final x = readDouble();
      final y = readDouble();
      if (hasZ) readDouble();
      if (hasM) readDouble();
      return LatLng(y, x);
    }

    if (baseType == _pointType) return [readPoint()];
    final count = readUint32();
    return [for (var i = 0; i < count; i++) readPoint()];
  }

  static String _name(int type) => type == _pointType ? 'Point' : 'LineString';
}
