import 'enums.dart';
import 'json.dart';
import 'profile.dart';

/// Row of `clubs`, or a row of the `club_info` / `my_clubs` RPCs, which add
/// [myRole] and [memberCount]. The invite code is owner-only (see
/// `club_invite_code`), so it's never part of a club row.
class Club {
  const Club({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
    this.photoUrl,
    this.myRole,
    this.memberCount,
  });

  /// Columns riders can read; `select *` on clubs is denied.
  static const columns = 'id,name,owner_id,photo_url,created_at';

  static const minName = 2;
  static const maxName = 60;

  final String id;
  final String name;
  final String ownerId;
  final String? photoUrl;
  final DateTime createdAt;

  /// The signed-in rider's role; null when not a member (or not loaded).
  final ClubRole? myRole;
  final int? memberCount;

  bool get isMember => myRole != null;
  bool get isOwner => myRole == ClubRole.owner;

  factory Club.fromJson(Json json) => Club(
    id: json['id'] as String,
    name: json['name'] as String,
    ownerId: json['owner_id'] as String,
    photoUrl: json['photo_url'] as String?,
    createdAt: parseTimestamp(json['created_at']),
    myRole: switch (json['my_role']) {
      final String v => ClubRole.fromValue(v),
      _ => null,
    },
    memberCount: toIntOrNull(json['member_count']),
  );
}

/// Row of `club_members`.
class ClubMember {
  const ClubMember({
    required this.clubId,
    required this.userId,
    required this.role,
    required this.createdAt,
    this.profile,
  });

  /// With the member's name and picture.
  static const columns =
      'club_id,user_id,role,created_at,'
      'profile:profiles!club_members_user_id_fkey(id,display_name,avatar_url)';

  final String clubId;
  final String userId;
  final ClubRole role;
  final DateTime createdAt;

  /// Name and picture, when selected with [columns].
  final ProfileSummary? profile;

  factory ClubMember.fromJson(Json json) => ClubMember(
    clubId: json['club_id'] as String,
    userId: json['user_id'] as String,
    role: ClubRole.fromValue(json['role'] as String),
    createdAt: parseTimestamp(json['created_at']),
    profile: switch (json['profile']) {
      final Json p => ProfileSummary.fromJson(p),
      _ => null,
    },
  );
}
