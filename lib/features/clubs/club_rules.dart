import '../../core/links.dart';
import '../../data/models/club.dart';
import '../../data/models/enums.dart';

/// Invite codes are 16 lowercase hex characters (`new_invite_code()`).
final _code = RegExp(r'^[0-9a-f]{16}$');

/// The invite code in what a rider pasted: the whole link
/// (https://pasyar.app/join/<code>, with or without https://), or just the
/// code. Null when it isn't one.
String? parseInviteCode(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  if (!text.contains('://') && text.contains('/')) text = 'https://$text';
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) {
    if (uri.host != AppLinks.domain && uri.host != 'www.${AppLinks.domain}') {
      return null;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 2 || segments.first != 'join') return null;
    text = segments.last;
  }
  final code = text.toLowerCase();
  return _code.hasMatch(code) ? code : null;
}

/// Why a club name can't be used, or null when it's fine.
String? clubNameError(String name) {
  final n = name.trim().length;
  if (n < Club.minName) return 'At least ${Club.minName} characters.';
  if (n > Club.maxName) return 'At most ${Club.maxName} characters.';
  return null;
}

/// "1 member", "12 members".
String memberCount(int n) => '$n ${n == 1 ? 'member' : 'members'}';

/// "Owner · 12 members", "Member · 3 members", or just the count.
String clubSubtitle(Club club) => [
  switch (club.myRole) {
    ClubRole.owner => 'Owner',
    ClubRole.member => 'Member',
    null => null,
  },
  if (club.memberCount case final n?) memberCount(n),
].nonNulls.join(' · ');
