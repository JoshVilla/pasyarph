import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AvatarRepository {
  /// Uploads a JPEG to `avatars/<userId>/avatar.jpg` (replacing any old one)
  /// and returns its public URL.
  Future<String> uploadAvatar(String userId, Uint8List jpeg);
}

class SupabaseAvatarRepository implements AvatarRepository {
  SupabaseAvatarRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'avatars';

  @override
  Future<String> uploadAvatar(String userId, Uint8List jpeg) async {
    final path = '$userId/avatar.jpg';
    final bucket = _client.storage.from(_bucket);
    await bucket.uploadBinary(
      path,
      jpeg,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'image/jpeg',
        cacheControl: '3600',
      ),
    );
    // Same path every time, so bust caches with a version parameter.
    final version = DateTime.now().millisecondsSinceEpoch;
    return '${bucket.getPublicUrl(path)}?v=$version';
  }
}
