import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

/// A photo already in storage, for [PostRepository.createPost].
class UploadedPhoto {
  const UploadedPhoto({
    required this.storagePath,
    required this.position,
    required this.width,
    required this.height,
  });

  final String storagePath;
  final int position;
  final int width;
  final int height;

  Map<String, Object> toJson() => {
    'storage_path': storagePath,
    'position': position,
    'width': width,
    'height': height,
  };
}

/// Why posting failed, with a message safe to show riders.
class PostException implements Exception {
  const PostException(this.code, this.message);

  final String code;
  final String message;

  static const offline = PostException(
    'offline',
    "Couldn't reach Pasyar. Check your connection and try again; your "
        'draft is saved.',
  );

  static const unknown = PostException(
    'unknown',
    "Something went wrong posting. Try again; your draft is saved.",
  );

  static const _messages = {
    'ride_not_found':
        "This ride hasn't reached Pasyar yet. Connect to the internet and "
        'try again.',
    'ride_too_old': 'Rides can only be posted within 7 days.',
    'ride_too_short': 'Ride at least a quarter of the loop to post it.',
    'ride_already_posted': 'This ride is already posted.',
    'bad_photos': 'Add 1 to 10 photos, then try again.',
  };

  /// Maps the errors create_post_from_ride raises.
  static PostException fromServer(String message) {
    for (final e in _messages.entries) {
      if (message.contains(e.key)) return PostException(e.key, e.value);
    }
    return unknown;
  }

  @override
  String toString() => 'PostException($code)';
}

abstract interface class PostRepository {
  /// The signed-in user (photos go under their folder), or null.
  String? get userId;

  /// Uploads to post-photos/[path], replacing a partial earlier upload.
  Future<void> uploadPhoto(String path, Uint8List jpeg);

  /// Saves the ride's loop if needed, then the post and its photos, in one
  /// transaction (create_post_from_ride). Throws [PostException].
  Future<void> createPost({
    required String postId,
    required String rideId,
    required String loopName,
    required String caption,
    required List<UploadedPhoto> photos,
  });
}

class SupabasePostRepository implements PostRepository {
  SupabasePostRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'post-photos';

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<void> uploadPhoto(String path, Uint8List jpeg) async {
    try {
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            jpeg,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
              cacheControl: '31536000',
            ),
          );
    } on Exception catch (e) {
      debugPrint('post: photo upload failed: $e');
      throw PostException.offline;
    }
  }

  @override
  Future<void> createPost({
    required String postId,
    required String rideId,
    required String loopName,
    required String caption,
    required List<UploadedPhoto> photos,
  }) async {
    try {
      await _client.rpc<void>(
        'create_post_from_ride',
        params: {
          'p_post_id': postId,
          'p_ride_id': rideId,
          'p_loop_name': loopName,
          'p_caption': caption,
          'p_photos': [for (final p in photos) p.toJson()],
        },
      );
    } on PostgrestException catch (e) {
      debugPrint('post: create_post_from_ride failed: ${e.code} ${e.message}');
      throw PostException.fromServer(e.message);
    } on Exception catch (e) {
      debugPrint('post: create_post_from_ride failed: $e');
      throw PostException.offline;
    }
  }
}
