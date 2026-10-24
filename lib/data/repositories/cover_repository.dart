import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Profile cover photos in the public `covers` bucket:
/// `covers/<user_id>/cover_<timestamp>.jpg`.
abstract interface class CoverRepository {
  /// Uploads a JPEG under a new name and returns its public URL.
  Future<String> upload(String userId, Uint8List jpeg);

  /// Deletes the file behind a cover URL. Best effort: a failure only
  /// leaves an orphan file, so it never throws.
  Future<void> delete(String url);
}

/// The path inside the covers bucket for one of its public URLs, or null.
String? coverPathFromUrl(String url) {
  const marker = '/storage/v1/object/public/covers/';
  final i = url.indexOf(marker);
  if (i < 0) return null;
  final path = url.substring(i + marker.length).split('?').first;
  return path.isEmpty ? null : Uri.decodeComponent(path);
}

class SupabaseCoverRepository implements CoverRepository {
  SupabaseCoverRepository(this._client);

  final SupabaseClient _client;

  StorageFileApi get _bucket => _client.storage.from('covers');

  @override
  Future<String> upload(String userId, Uint8List jpeg) async {
    final path = '$userId/cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _bucket.uploadBinary(
      path,
      jpeg,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        // A new name every time, so it can be cached for good.
        cacheControl: '31536000',
      ),
    );
    return _bucket.getPublicUrl(path);
  }

  @override
  Future<void> delete(String url) async {
    final path = coverPathFromUrl(url);
    if (path == null) return;
    try {
      await _bucket.remove([path]);
    } on Exception catch (e) {
      debugPrint('covers: delete $path failed: $e');
    }
  }
}
