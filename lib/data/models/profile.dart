import 'enums.dart';
import 'json.dart';

/// Row of `profiles`. Created automatically on sign-up.
class Profile {
  const Profile({
    required this.id,
    required this.createdAt,
    this.fullName,
    this.displayName,
    this.avatarUrl,
    this.bikeType,
    this.homeArea,
    this.onboardingCompleted = false,
    this.termsAcceptedAt,
  });

  final String id;
  final String? fullName;
  final String? displayName;
  final String? avatarUrl;
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
    avatarUrl: json['avatar_url'] as String?,
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
    'avatar_url': avatarUrl,
    'bike_type': bikeType?.value,
    'home_area': homeArea,
    'onboarding_completed': onboardingCompleted,
    'terms_accepted_at': termsAcceptedAt?.toUtc().toIso8601String(),
  };
}

/// Author info embedded in feed rows.
class ProfileSummary {
  const ProfileSummary({required this.id, this.displayName, this.avatarUrl});

  final String id;
  final String? displayName;
  final String? avatarUrl;

  factory ProfileSummary.fromJson(Json json) => ProfileSummary(
    id: json['id'] as String,
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );
}
