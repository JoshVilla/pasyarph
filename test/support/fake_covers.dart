import 'dart:typed_data';

import 'package:pasyarph/data/repositories/cover_repository.dart';

/// In-memory covers: uploads get a fake public URL; deletes are recorded.
class FakeCoverRepository implements CoverRepository {
  final uploads = <String>[];
  final deleted = <String>[];
  bool fail = false;
  var _n = 0;

  @override
  Future<String> upload(String userId, Uint8List jpeg) async {
    if (fail) throw Exception('offline');
    final url =
        'https://x.supabase.co/storage/v1/object/public/covers/$userId/cover_${++_n}.jpg';
    uploads.add(url);
    return url;
  }

  @override
  Future<void> delete(String url) async => deleted.add(url);
}
