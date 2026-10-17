import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pasyarph/core/location/location_permission.dart';
import 'package:pasyarph/core/location/location_provider.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/core/location/speed.dart';

import '../../support/fake_services.dart';

const _cordon = LatLng(16.6720, 121.4570);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('speedKmh', () {
    test('converts m/s to km/h', () {
      expect(speedKmh(10), closeTo(36, 1e-9));
    });

    test('treats unknown and negative readings as stopped', () {
      expect(speedKmh(-1), 0);
      expect(speedKmh(double.nan), 0);
      expect(speedKmh(0), 0);
    });

    test('moving means faster than 10 km/h', () {
      expect(isMovingAt(10), isFalse);
      expect(isMovingAt(10.1), isTrue);
    });
  });

  group('LocationProvider', () {
    late FakeLocationPermission permission;
    late FakePositionSource source;
    late LocationProvider provider;

    LocationProvider make() => provider = LocationProvider(
      permissions: permission,
      positions: source,
    );

    setUp(() {
      permission = FakeLocationPermission();
      source = FakePositionSource();
    });
    tearDown(() => provider.dispose());

    test('granted: streams fixes and speed', () async {
      await make().start();
      expect(provider.status, LocationStatus.on);
      expect(provider.hasFix, isFalse);

      source.emit(const RiderFix(point: _cordon, speedMps: 5));
      await Future<void>.delayed(Duration.zero);
      expect(provider.position, _cordon);
      expect(provider.speedKmh, closeTo(18, 1e-9));
      expect(provider.isMoving, isTrue);
      expect(provider.hasFix, isTrue);
    });

    test('uses the last known fix until a live one arrives', () async {
      source.last = const RiderFix(point: _cordon);
      await make().start();
      expect(provider.position, _cordon);
    });

    test('denied: banner asks for permission, then listens', () async {
      permission.answer = LocationAccess.denied;
      await make().start();
      expect(provider.status, LocationStatus.denied);

      permission.answer = LocationAccess.granted;
      await provider.fix();
      expect(permission.requests, 1);
      expect(provider.status, LocationStatus.on);
    });

    test('denied forever: banner opens app settings', () async {
      permission.answer = LocationAccess.deniedForever;
      await make().start();
      expect(provider.status, LocationStatus.deniedForever);
      await provider.fix();
      expect(permission.requests, 0);
    });

    test('phone location off: banner opens location settings', () async {
      source.enabled = false;
      await make().start();
      expect(provider.status, LocationStatus.serviceOff);
      await provider.fix();
      expect(source.settingsOpened, 1);
    });

    test('stream error means location was turned off', () async {
      await make().start();
      source.controller.addError(Exception('off'));
      await Future<void>.delayed(Duration.zero);
      expect(provider.status, LocationStatus.serviceOff);
    });
  });
}
