import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/post_repository.dart';
import '../../../data/repositories/ride_history_repository.dart';
import '../../ride/loop_stats.dart';
import '../photo_processing.dart';
import '../post_draft.dart';

/// A photo the rider picked, before checks and compression.
class PickedPhoto {
  const PickedPhoto(this.bytes);

  final Uint8List bytes;
}

enum ComposerPhase { loading, missing, editing, posting, posted }

/// The post screen: one ride, its draft (photos and caption), and posting
/// (uploads, then create_post_from_ride).
class PostComposer extends ChangeNotifier {
  PostComposer({
    required this.rideId,
    required RideHistoryRepository history,
    required PostRepository posts,
    required PostDraftStore drafts,
    Future<ProcessedPhoto?> Function(Uint8List)? process,
    DateTime Function()? clock,
  }) : _history = history,
       _posts = posts,
       _drafts = drafts,
       _process = process ?? processPhoto,
       _now = clock ?? DateTime.now;

  final String rideId;
  final RideHistoryRepository _history;
  final PostRepository _posts;
  final PostDraftStore _drafts;
  final Future<ProcessedPhoto?> Function(Uint8List) _process;
  final DateTime Function() _now;

  static const maxPhotos = 10;

  ComposerPhase _phase = ComposerPhase.loading;
  RideSummary? _ride;
  PostDraft? _draft;
  bool _adding = false;
  int _uploaded = 0;
  String? _error;
  List<String> _refused = const [];
  bool _disposed = false;

  ComposerPhase get phase => _phase;
  RideSummary? get ride => _ride;
  List<DraftPhoto> get photos => List.unmodifiable(_draft?.photos ?? const []);
  String get caption => _draft?.caption ?? '';
  int get remaining => maxPhotos - photos.length;
  bool get adding => _adding;

  /// Photos uploaded so far while posting, for "POSTING 2 / 4".
  int get uploaded => _uploaded;

  /// Why the last post attempt failed.
  String? get error => _error;

  /// One line per refused photo from the last pick.
  List<String> get refused => _refused;

  /// Why this ride can't be posted, or null.
  String? get blockedReason {
    final r = _ride;
    if (r == null) return null;
    if (r.posted) return 'This ride is already posted.';
    if (!r.longEnough) return 'Ride at least a quarter of the loop to post it.';
    if (r.isExpired(_now())) return 'Rides can only be posted within 7 days.';
    return null;
  }

  bool get canPost =>
      _phase == ComposerPhase.editing &&
      !_adding &&
      photos.isNotEmpty &&
      blockedReason == null;

  /// Main stop as the ride screens show it, if the loop had one.
  StopInfo? get stop {
    final s = _ride?.stop;
    if (s == null) return null;
    return StopInfo(
      location: s.location,
      metersIn: 0,
      name: s.name,
      type: s.type,
    );
  }

  Future<void> load() async {
    final ride = await _history.byId(rideId);
    if (ride == null) {
      _set(ComposerPhase.missing);
      return;
    }
    _ride = ride;
    _draft = await _drafts.load(rideId) ?? PostDraft(rideId: rideId);
    _set(ride.posted ? ComposerPhase.posted : ComposerPhase.editing);
  }

  /// Compresses the photos and keeps them in the draft. Any photo goes:
  /// what riders post is up to them. Ones over the limit or unreadable end
  /// up in [refused].
  Future<void> addPhotos(List<PickedPhoto> picked) async {
    final draft = _draft;
    final ride = _ride;
    if (draft == null || ride == null || _adding) return;
    _adding = true;
    _refused = const [];
    notifyListeners();

    final refused = <String>[];
    final dir = await _drafts.photoDir(rideId);
    var n = 0;
    for (final p in picked) {
      n++;
      if (draft.photos.length >= maxPhotos) {
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
      draft.photos.add(
        DraftPhoto(path: file.path, width: out.width, height: out.height),
      );
    }
    await _drafts.save(draft);
    _adding = false;
    _refused = refused;
    if (!_disposed) notifyListeners();
  }

  Future<void> removePhoto(int index) async {
    final draft = _draft;
    if (draft == null || _phase != ComposerPhase.editing) return;
    final removed = draft.photos.removeAt(index);
    // Positions shifted: the ones after it go up again.
    for (var i = index; i < draft.photos.length; i++) {
      draft.photos[i] = draft.photos[i].copyWith(uploaded: false);
    }
    await _drafts.save(draft);
    notifyListeners();
    final f = File(removed.path);
    if (f.existsSync()) await f.delete();
  }

  void setCaption(String value) {
    final draft = _draft;
    if (draft == null || draft.caption == value) return;
    draft.caption = value;
    _drafts.save(draft);
  }

  void clearRefused() {
    if (_refused.isEmpty) return;
    _refused = const [];
    notifyListeners();
  }

  /// Syncs the ride, uploads photos not yet uploaded, then creates the
  /// post. True when posted; otherwise [error] says why and the draft stays.
  Future<bool> post() async {
    final draft = _draft;
    final ride = _ride;
    if (!canPost || draft == null || ride == null) return false;
    final uid = _posts.userId;
    if (uid == null) {
      _error = 'Log in again to post.';
      notifyListeners();
      return false;
    }
    _phase = ComposerPhase.posting;
    _error = null;
    _uploaded = draft.photos.where((p) => p.uploaded).length;
    notifyListeners();

    try {
      if (!ride.synced && !await _history.sync()) {
        throw PostException.offline;
      }
      final uploads = <UploadedPhoto>[];
      for (var i = 0; i < draft.photos.length; i++) {
        final photo = draft.photos[i];
        final path = '$uid/${draft.postId}/$i.jpg';
        if (!photo.uploaded) {
          await _posts.uploadPhoto(path, await File(photo.path).readAsBytes());
          draft.photos[i] = photo.copyWith(uploaded: true);
          await _drafts.save(draft);
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

      final retry = draft.submitted;
      draft.submitted = true;
      await _drafts.save(draft);
      try {
        await _posts.createPost(
          postId: draft.postId,
          rideId: rideId,
          loopName: _loopName(ride),
          caption: draft.caption,
          photos: uploads,
        );
      } on PostException catch (e) {
        // The first call went through but its reply was lost.
        if (!(retry && e.code == 'ride_already_posted')) rethrow;
      }

      await _history.markPosted(rideId);
      await _drafts.delete(rideId);
      _ride = ride.copyWith(posted: true);
      _set(ComposerPhase.posted);
      return true;
    } on PostException catch (e) {
      _error = e.message;
      _set(ComposerPhase.editing);
      return false;
    }
  }

  /// "Bangaan View loop", or "52 km loop" without a named stop.
  static String _loopName(RideSummary ride) {
    final name = ride.stop?.name;
    return name == null ? '${formatDistance(ride.loopM)} loop' : '$name loop';
  }

  void _set(ComposerPhase phase) {
    _phase = phase;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
