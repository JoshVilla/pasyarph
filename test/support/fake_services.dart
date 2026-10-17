import 'dart:typed_data';

import 'package:pasyarph/core/location/location_permission.dart';
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
