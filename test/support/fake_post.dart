import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pasyarph/data/repositories/post_repository.dart';
import 'package:pasyarph/features/post/post_draft.dart';

class FakePosts implements PostRepository {
  final uploads = <String>[];
  final created = <Map<String, Object>>[];

  /// Upload number (1-based) that fails once.
  int? failUpload;
  final createErrors = <PostException>[];

  @override
  String? userId = 'user-1';

  @override
  Future<void> uploadPhoto(String path, Uint8List jpeg) async {
    if (failUpload == uploads.length + 1) {
      failUpload = null;
      throw PostException.offline;
    }
    uploads.add(path);
  }

  @override
  Future<void> createPost({
    required String postId,
    required String rideId,
    required String loopName,
    required String caption,
    required List<UploadedPhoto> photos,
  }) async {
    if (createErrors.isNotEmpty) throw createErrors.removeAt(0);
    created.add({
      'postId': postId,
      'rideId': rideId,
      'loopName': loopName,
      'caption': caption,
      'paths': [for (final p in photos) p.storagePath],
    });
  }
}

class MemoryDrafts implements PostDraftStore {
  MemoryDrafts(this.root);

  final Directory root;
  final saved = <String, Map<String, dynamic>>{};

  @override
  Future<PostDraft?> load(String rideId) async {
    final json = saved[rideId];
    return json == null ? null : PostDraft.fromJson(json);
  }

  @override
  Future<void> save(PostDraft draft) async =>
      saved[draft.rideId] = draft.toJson();

  @override
  Future<void> delete(String rideId) async => saved.remove(rideId);

  @override
  Future<Directory> photoDir(String rideId) =>
      Directory('${root.path}/$rideId').create(recursive: true);
}
