import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../data/ids.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/post_repository.dart';
import '../photo_processing.dart';
import 'post_composer.dart' show PickedPhoto;

/// A photo on a text post, compressed into a temporary file.
class TextPostPhoto {
  const TextPostPhoto({
    required this.path,
    required this.width,
    required this.height,
    this.uploaded = false,
  });

  final String path;
  final int width;
  final int height;
  final bool uploaded;

  TextPostPhoto copyWith({bool? uploaded}) => TextPostPhoto(
    path: path,
    width: width,
    height: height,
    uploaded: uploaded ?? this.uploaded,
  );
}

/// The "Write a post" screen: words, 0-10 photos, who sees it, and posting
/// (uploads, then create_text_post). Nothing is kept if the rider leaves.
class TextPostComposer extends ChangeNotifier {
  TextPostComposer({
    required PostRepository posts,
    Future<ProcessedPhoto?> Function(Uint8List)? process,
    Future<Directory> Function()? photoDir,
  }) : _posts = posts,
       _process = process ?? processPhoto,
       _photoDir =
           photoDir ?? (() => Directory.systemTemp.createTemp('pasyar_post'));

  final PostRepository _posts;
  final Future<ProcessedPhoto?> Function(Uint8List) _process;
  final Future<Directory> Function() _photoDir;

  static const maxPhotos = 10;
  static const maxLength = 2000;

  /// Same id on a retry, so a post whose reply was lost isn't made twice.
  final String postId = newId();

  String _text = '';
  final _photos = <TextPostPhoto>[];
  LoopVisibility _visibility = LoopVisibility.public;
  String? _clubId;
  bool _adding = false;
  bool _posting = false;
  int _uploaded = 0;
  String? _error;
  List<String> _refused = const [];
  Directory? _dir;
  bool _disposed = false;

  String get text => _text;
  List<TextPostPhoto> get photos => List.unmodifiable(_photos);
  int get remaining => maxPhotos - _photos.length;
  LoopVisibility get visibility => _visibility;
  String? get clubId => _clubId;
  bool get adding => _adding;
  bool get posting => _posting;

  /// Photos uploaded so far while posting, for "POSTING 2 / 4".
  int get uploaded => _uploaded;

  /// Why the last post attempt failed.
  String? get error => _error;

  /// One line per refused photo from the last pick.
  List<String> get refused => _refused;

  bool get canPost =>
      !_posting &&
      !_adding &&
      _text.trim().isNotEmpty &&
      _text.trim().length <= maxLength &&
      (_visibility != LoopVisibility.club || _clubId != null);

  void setText(String value) {
    if (_text == value) return;
    final wasEmpty = _text.trim().isEmpty;
    _text = value;
    // Only the POST button cares, and only when it flips.
    if (wasEmpty != value.trim().isEmpty) notifyListeners();
  }

  void setVisibility(LoopVisibility v, {String? clubId}) {
    _visibility = v;
    if (v != LoopVisibility.club) {
      _clubId = null;
    } else if (clubId != null) {
      _clubId = clubId;
    }
    notifyListeners();
  }

  Future<void> addPhotos(List<PickedPhoto> picked) async {
    if (_adding || _posting) return;
    _adding = true;
    _refused = const [];
    notifyListeners();

    final refused = <String>[];
    final dir = _dir ??= await _photoDir();
    var n = 0;
    for (final p in picked) {
      n++;
      if (_photos.length >= maxPhotos) {
        refused.add('Photo $n: you already have $maxPhotos photos.');
        continue;
      }
      final out = await _process(p.bytes);
      if (out == null) {
        refused.add("Photo $n couldn't be read.");
        continue;
      }
      final file = File(
        '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$n.jpg',
      );
      await file.writeAsBytes(out.jpeg, flush: true);
      _photos.add(
        TextPostPhoto(path: file.path, width: out.width, height: out.height),
      );
    }
    _adding = false;
    _refused = refused;
    if (!_disposed) notifyListeners();
  }

  void removePhoto(int index) {
    if (_posting) return;
    _photos.removeAt(index);
    // Positions shifted: the ones after it go up again.
    for (var i = index; i < _photos.length; i++) {
      _photos[i] = _photos[i].copyWith(uploaded: false);
    }
    notifyListeners();
  }

  /// Uploads photos not yet uploaded, then posts. True when posted;
  /// otherwise [error] says why and everything stays for another try.
  Future<bool> post() async {
    if (!canPost) return false;
    final uid = _posts.userId;
    if (uid == null) {
      _error = 'Log in again to post.';
      notifyListeners();
      return false;
    }
    _posting = true;
    _error = null;
    _uploaded = _photos.where((p) => p.uploaded).length;
    notifyListeners();

    try {
      final uploads = <UploadedPhoto>[];
      for (var i = 0; i < _photos.length; i++) {
        final photo = _photos[i];
        final path = '$uid/$postId/$i.jpg';
        if (!photo.uploaded) {
          await _posts.uploadPhoto(path, await File(photo.path).readAsBytes());
          _photos[i] = photo.copyWith(uploaded: true);
          _uploaded++;
          if (!_disposed) notifyListeners();
        }
        uploads.add(
          UploadedPhoto(
            storagePath: path,
            position: i,
            width: photo.width,
            height: photo.height,
          ),
        );
      }
      await _posts.createTextPost(
        postId: postId,
        text: _text.trim(),
        visibility: _visibility,
        clubId: _clubId,
        photos: uploads,
      );
      _posting = false;
      if (!_disposed) notifyListeners();
      return true;
    } on PostException catch (e) {
      // The shared messages promise a saved draft; this screen keeps the
      // post only while it's open.
      _error = switch (e.code) {
        'offline' =>
          "Couldn't reach Pasyar. Check your connection and try again.",
        'unknown' => 'Something went wrong posting. Try again.',
        _ => e.message,
      };
      _posting = false;
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final dir = _dir;
    if (dir != null) dir.delete(recursive: true).ignore();
    super.dispose();
  }
}
