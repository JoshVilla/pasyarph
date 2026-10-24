import 'package:flutter/foundation.dart';

import '../../../data/repositories/cover_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// The signed-in rider's cover photo: upload a new one (replacing the old
/// file), or remove it. App-wide, so the Me tab and Edit profile show the
/// same upload.
class CoverController extends ChangeNotifier {
  CoverController({required AuthProvider auth, required CoverRepository covers})
    : _auth = auth,
      _covers = covers;

  final AuthProvider _auth;
  final CoverRepository _covers;

  static const failed =
      "Couldn't update your cover. Check your connection and try again.";

  bool _busy = false;

  /// Uploading or removing; the banner shows progress.
  bool get busy => _busy;

  String? get coverUrl => _auth.profile?.coverUrl;

  /// Uploads [jpeg] as the new cover, then deletes the old file. Returns
  /// why it failed (the old cover stays), or null.
  Future<String?> save(Uint8List jpeg) => _run(() async {
    final userId = _auth.user?.id;
    if (userId == null) return failed;
    final old = coverUrl;
    final url = await _covers.upload(userId, jpeg);
    try {
      await _auth.updateProfile({'cover_url': url});
    } on Exception {
      // Not saved: don't leave the new file behind.
      await _covers.delete(url);
      rethrow;
    }
    if (old != null) await _covers.delete(old);
    return null;
  });

  /// Back to the default banner; deletes the file. Returns why it failed,
  /// or null.
  Future<String?> remove() => _run(() async {
    final old = coverUrl;
    if (old == null) return null;
    await _auth.updateProfile({'cover_url': null});
    await _covers.delete(old);
    return null;
  });

  Future<String?> _run(Future<String?> Function() work) async {
    if (_busy) return null;
    _busy = true;
    notifyListeners();
    try {
      return await work();
    } on Exception catch (e) {
      debugPrint('cover: $e');
      return failed;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
