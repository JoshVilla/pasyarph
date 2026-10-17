import 'enums.dart';
import 'json.dart';

/// Row of `clubs`.
class Club {
  const Club({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final DateTime createdAt;

  factory Club.fromJson(Json json) => Club(
    id: json['id'] as String,
    name: json['name'] as String,
    ownerId: json['owner_id'] as String,
    createdAt: parseTimestamp(json['created_at']),
  );
}

/// Row of `club_members`.
class ClubMember {
  const ClubMember({
    required this.clubId,
    required this.userId,
    required this.role,
    required this.createdAt,
  });

  final String clubId;
  final String userId;
  final ClubRole role;
  final DateTime createdAt;

  factory ClubMember.fromJson(Json json) => ClubMember(
    clubId: json['club_id'] as String,
    userId: json['user_id'] as String,
    role: ClubRole.fromValue(json['role'] as String),
    createdAt: parseTimestamp(json['created_at']),
  );
}
