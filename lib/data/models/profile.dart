import 'enums.dart';
import 'json.dart';

/// Row of `profiles`. Created automatically on sign-up.
class Profile {
  const Profile({
    required this.id,
    required this.createdAt,
    this.fullName,
    this.displayName,
    this.username,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.bikeType,
    this.homeArea,
    this.onboardingCompleted = false,
    this.termsAcceptedAt,
  });

  final String id;
  final String? fullName;
  final String? displayName;

  /// Unique handle, shown as @username. Null until set in Edit profile.
  final String? username;

  /// Up to 150 characters.
  final String? bio;
  final String? avatarUrl;

  /// Wide banner at the top of the profile.
  final String? coverUrl;
  final BikeType? bikeType;

  /// Town only, e.g. "Cordon, Isabela".
  final String? homeArea;
  final bool onboardingCompleted;
  final DateTime? termsAcceptedAt;
  final DateTime createdAt;

  factory Profile.fromJson(Json json) => Profile(
    id: json['id'] as String,
    fullName: json['full_name'] as String?,
    displayName: json['display_name'] as String?,
    username: json['username'] as String?,
    bio: json['bio'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    coverUrl: json['cover_url'] as String?,
    bikeType: switch (json['bike_type']) {
      final String v => BikeType.fromValue(v),
      _ => null,
    },
    homeArea: json['home_area'] as String?,
    onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
    termsAcceptedAt: parseTimestampOrNull(json['terms_accepted_at']),
    createdAt: parseTimestamp(json['created_at']),
  );

  /// Columns the owner may update.
  Json toUpdateJson() => {
    'full_name': fullName,
    'display_name': displayName,
    'username': username,
    'bio': bio,
    'avatar_url': avatarUrl,
    'cover_url': coverUrl,
    'bike_type': bikeType?.value,
    'home_area': homeArea,
    'onboarding_completed': onboardingCompleted,
    'terms_accepted_at': termsAcceptedAt?.toUtc().toIso8601String(),
  };
}

/// Author info embedded in feed rows.
class ProfileSummary {
  const ProfileSummary({
    required this.id,
    this.displayName,
    this.avatarUrl,
    this.username,
  });

  final String id;
  final String? displayName;
  final String? avatarUrl;
  final String? username;

  factory ProfileSummary.fromJson(Json json) => ProfileSummary(
    id: json['id'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    username: json['username'] as String?,
  );
}

/// A row of the `rider_profile` RPC: what other riders see, with follows.
class RiderProfile {
  const RiderProfile({
    required this.id,
    this.displayName,
    this.username,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.bikeType,
    this.homeArea,
    this.followerCount = 0,
    this.followingCount = 0,
    this.followedByMe = false,
    this.riddenM = 0,
    this.loopsRidden = 0,
    this.posts = 0,
  });

  final String id;
  final String? displayName;
  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String? coverUrl;
  final BikeType? bikeType;

  /// Town only.
  final String? homeArea;
  final int followerCount;
  final int followingCount;
  final bool followedByMe;

  /// Profile stats: km ridden (meters), loops ridden, posts.
  final int riddenM;
  final int loopsRidden;
  final int posts;

  RiderProfile copyWith({bool? followedByMe, int? followerCount}) =>
      RiderProfile(
        id: id,
        displayName: displayName,
        username: username,
        bio: bio,
        avatarUrl: avatarUrl,
        coverUrl: coverUrl,
        bikeType: bikeType,
        homeArea: homeArea,
        followerCount: followerCount ?? this.followerCount,
        followingCount: followingCount,
        followedByMe: followedByMe ?? this.followedByMe,
        riddenM: riddenM,
        loopsRidden: loopsRidden,
        posts: posts,
      );

  factory RiderProfile.fromJson(Json json) => RiderProfile(
    id: json['id'] as String,
    displayName: json['display_name'] as String?,
    username: json['username'] as String?,
    bio: json['bio'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    coverUrl: json['cover_url'] as String?,
    bikeType: switch (json['bike_type']) {
      final String v => BikeType.fromValue(v),
      _ => null,
    },
    homeArea: json['home_area'] as String?,
    followerCount: toIntOrNull(json['follower_count']) ?? 0,
    followingCount: toIntOrNull(json['following_count']) ?? 0,
    followedByMe: json['followed_by_me'] as bool? ?? false,
    riddenM: toIntOrNull(json['ridden_m']) ?? 0,
    loopsRidden: toIntOrNull(json['loops_ridden']) ?? 0,
    posts: toIntOrNull(json['posts']) ?? 0,
  );
}
