import 'dart:async';
import 'dart:typed_data';

import 'package:pasyarph/core/location/location_permission.dart';
import 'package:pasyarph/core/location/position_source.dart';
import 'package:pasyarph/data/repositories/avatar_repository.dart';

class FakeAvatarRepository implements AvatarRepository {
  final uploads = <String>[];

  @override
  Future<String> uploadAvatar(String userId, Uint8List jpeg) async {
    uploads.add(userId);
    return 'https://example.test/avatars/$userId/avatar.jpg';
  }
}

class FakeLocationPermission implements LocationPermissionService {
  FakeLocationPermission([this.answer = LocationAccess.granted]);

  LocationAccess answer;
  int requests = 0;

  @override
  Future<LocationAccess> current() async => answer;

  @override
  Future<LocationAccess> requestWhileInUse() async {
    requests++;
    return answer;
  }

  @override
  Future<bool> openSettings() async => true;
}

class FakePositionSource implements PositionSource {
  FakePositionSource({this.enabled = true, this.last});

  bool enabled;
  RiderFix? last;
  int settingsOpened = 0;
  final controller = StreamController<RiderFix>.broadcast();

  void emit(RiderFix fix) => controller.add(fix);

  @override
  Future<bool> serviceEnabled() async => enabled;

  @override
  Future<RiderFix?> lastKnown() async => last;

  @override
  Stream<RiderFix> fixes() => controller.stream;

  @override
  Future<bool> openLocationSettings() async {
    settingsOpened++;
    return true;
  }
}
