import '../../data/models/enums.dart';

/// "Big bike", for the profile's detail line.
String bikeLabel(BikeType bike) => switch (bike) {
  BikeType.scooter => 'Scooter',
  BikeType.underbone => 'Underbone',
  BikeType.bigBike => 'Big bike',
  BikeType.dualSport => 'Dual-sport',
};

/// Usernames: lowercase letters, numbers, dot and underscore (as checked by
/// `profiles_username_format`).
final _username = RegExp(r'^[a-z0-9._]{3,20}$');

const maxBio = 150;

/// What's saved for a typed username: trimmed, without a leading @,
/// lowercase.
String normalizeUsername(String input) {
  var u = input.trim().toLowerCase();
  if (u.startsWith('@')) u = u.substring(1);
  return u;
}

/// Why [input] can't be a username, or null when it can.
String? usernameError(String input) {
  final u = normalizeUsername(input);
  if (u.isEmpty) return 'Pick a username so riders can find you.';
  if (u.length < 3) return 'At least 3 characters.';
  if (u.length > 20) return 'At most 20 characters.';
  if (!_username.hasMatch(u)) {
    return 'Use letters, numbers, dots and underscores only.';
  }
  return null;
}

String? bioError(String input) =>
    input.trim().length > maxBio ? 'At most $maxBio characters.' : null;

/// "@ana.rides · Underbone · Cordon, Isabela", leaving out what's missing.
String handleLine({String? username, BikeType? bike, String? homeArea}) => [
  if (username != null && username.isNotEmpty) '@$username',
  if (bike != null) bikeLabel(bike),
  if (homeArea != null && homeArea.trim().isNotEmpty) homeArea.trim(),
].join(' · ');
