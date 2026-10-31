import '../../data/models/enums.dart';
import '../../data/models/loop.dart';
import '../ride/loop_stats.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Just now", "12 min ago", "2 h ago", "Yesterday", "3 days ago", "Oct 4".
String timeAgo(DateTime at, DateTime now) {
  final local = at.toLocal();
  final age = now.difference(local);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inMinutes < 60) return '${age.inMinutes} min ago';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final days = today.difference(day).inDays;
  if (days == 0) return '${age.inHours} h ago';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  final date = '${_months[local.month - 1]} ${local.day}';
  return local.year == now.year ? date : '$date, ${local.year}';
}

/// "6 km from you"; "800 m from you" under a kilometre.
String distanceFromYou(double meters) {
  if (meters < 1000) return '${(meters / 100).round() * 100} m from you';
  return '${(meters / 1000).round()} km from you';
}

/// Who sees the loop: "Public", "My clubs", "Only me".
String visibilityLabel(LoopVisibility v) => switch (v) {
  LoopVisibility.public => 'Public',
  LoopVisibility.club => 'My clubs',
  LoopVisibility.private => 'Only me',
};

/// "at Talon Falls", or null without a named stop.
String? stopLabel(MainStop? stop) =>
    stop?.name == null ? null : 'at ${stop!.name}';

/// "118 km · 3 h 50".
String loopStats(Loop loop) =>
    '${formatDistance(loop.distanceM)} · ${formatRideTime(loop.durationS)}';

final _distanceName = RegExp(r'^\d+(\.\d)? km loop$');

/// A loop posted without a named stop is called by its distance
/// ("25 km loop"), which says nothing on its own.
bool isDistanceName(String name) => _distanceName.hasMatch(name.trim());

/// "rode Sunday Falls Loop", but "rode a 25 km loop".
String rodeArticle(Loop loop) => isDistanceName(loop.name) ? 'a ' : '';

/// The loop card's title and detail lines. A loop named by its distance
/// is titled by where it is ("Loop in Ifugao"), and the distance isn't
/// repeated next to a title that already says it.
({String title, List<String> details}) loopCardText(Loop loop, String? away) {
  final province = loop.province;
  final time = formatRideTime(loop.durationS);
  if (isDistanceName(loop.name)) {
    return province != null
        ? (title: 'Loop in $province', details: [loopStats(loop), ?away])
        : (
            title: loop.name,
            details: [
              [time, ?away].join(' · '),
            ],
          );
  }
  return province != null
      ? (
          title: loop.name,
          details: [
            loopStats(loop),
            [province, ?away].join(' · '),
          ],
        )
      : (
          title: loop.name,
          details: [
            [loopStats(loop), ?away].join(' · '),
          ],
        );
}

/// "1 like", "48 likes".
String plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';
