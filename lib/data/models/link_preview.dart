import 'json.dart';

/// Whether a share link can be opened by the rider (`link_preview()`).
enum LinkStatus {
  /// Public, the rider's own, or a club loop they're in.
  ok,

  /// A club loop and the rider isn't a member.
  club,

  /// Someone else's private loop.
  private,

  /// Deleted, or never existed.
  missing,
}

/// What a /l/ or /p/ link points at, as far as the rider may know.
class LinkPreview {
  const LinkPreview({
    required this.status,
    this.loopId,
    this.name,
    this.distanceM,
    this.clubName,
  });

  final LinkStatus status;

  /// [LinkStatus.ok] only.
  final String? loopId;
  final String? name;
  final int? distanceM;

  /// [LinkStatus.club] only.
  final String? clubName;

  factory LinkPreview.fromJson(Json json) => LinkPreview(
    status: LinkStatus.values.asNameMap()[json['status']] ?? LinkStatus.missing,
    loopId: json['loop_id'] as String?,
    name: json['name'] as String?,
    distanceM: (json['distance_m'] as num?)?.toInt(),
    clubName: json['club_name'] as String?,
  );
}
