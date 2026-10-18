import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/ids.dart';
import '../../data/models/json.dart';

/// A processed photo saved on the phone, waiting to be posted.
class DraftPhoto {
  const DraftPhoto({
    required this.path,
    required this.width,
    required this.height,
    this.uploaded = false,
  });

  /// JPEG file in the draft's folder.
  final String path;
  final int width;
  final int height;

  /// Already in storage at its position (cleared when photos move).
  final bool uploaded;

  DraftPhoto copyWith({bool? uploaded}) => DraftPhoto(
    path: path,
    width: width,
    height: height,
    uploaded: uploaded ?? this.uploaded,
  );

  factory DraftPhoto.fromJson(Json json) => DraftPhoto(
    path: json['path'] as String,
    width: (json['width'] as num).toInt(),
    height: (json['height'] as num).toInt(),
    uploaded: json['uploaded'] as bool? ?? false,
  );

  Json toJson() => {
    'path': path,
    'width': width,
    'height': height,
    'uploaded': uploaded,
  };
}

/// An unfinished post for one ride. Survives app restarts.
class PostDraft {
  PostDraft({
    required this.rideId,
    String? postId,
    this.caption = '',
    List<DraftPhoto>? photos,
    this.submitted = false,
  }) : postId = postId ?? newId(),
       photos = photos ?? [];

  final String rideId;

  /// Picked once, so retried uploads land in the same folder.
  final String postId;
  String caption;
  final List<DraftPhoto> photos;

  /// create_post_from_ride was called at least once: an "already posted"
  /// reply on a retry means the first call went through.
  bool submitted;

  factory PostDraft.fromJson(Json json) => PostDraft(
    rideId: json['ride_id'] as String,
    postId: json['post_id'] as String,
    caption: json['caption'] as String? ?? '',
    photos: [
      for (final p in json['photos'] as List? ?? const [])
        DraftPhoto.fromJson(p as Json),
    ],
    submitted: json['submitted'] as bool? ?? false,
  );

  Json toJson() => {
    'ride_id': rideId,
    'post_id': postId,
    'caption': caption,
    'photos': [for (final p in photos) p.toJson()],
    'submitted': submitted,
  };
}

abstract interface class PostDraftStore {
  Future<PostDraft?> load(String rideId);
  Future<void> save(PostDraft draft);

  /// Removes the draft and its photo files.
  Future<void> delete(String rideId);

  /// Folder for the draft's photo files (created if needed).
  Future<Directory> photoDir(String rideId);
}

/// Drafts in shared preferences, photos in the app's documents folder.
class LocalPostDraftStore implements PostDraftStore {
  const LocalPostDraftStore();

  static String _key(String rideId) => 'post_draft_$rideId';

  @override
  Future<PostDraft?> load(String rideId) async {
    final raw = await SharedPreferencesAsync().getString(_key(rideId));
    if (raw == null) return null;
    final draft = PostDraft.fromJson(jsonDecode(raw) as Json);
    // Files can vanish (storage cleared); drop those photos.
    draft.photos.retainWhere((p) => File(p.path).existsSync());
    return draft;
  }

  @override
  Future<void> save(PostDraft draft) => SharedPreferencesAsync().setString(
    _key(draft.rideId),
    jsonEncode(draft.toJson()),
  );

  @override
  Future<void> delete(String rideId) async {
    await SharedPreferencesAsync().remove(_key(rideId));
    final dir = await photoDir(rideId);
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  @override
  Future<Directory> photoDir(String rideId) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory(
      '${docs.path}/post_drafts/$rideId',
    ).create(recursive: true);
  }
}
