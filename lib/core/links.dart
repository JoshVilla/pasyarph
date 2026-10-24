import '../features/ride/loop_stats.dart';

/// Public web pages and share links. The site (assetlinks.json, the "not
/// installed" pages, terms and privacy) lives in site/ and is deployed to
/// Cloudflare Pages. Android opens links on [domain] in the app (App Links,
/// see AndroidManifest.xml).
abstract final class AppLinks {
  // TODO(launch): moving to a real domain breaks links already shared;
  // keep this site redirecting if that happens (Prompt 21).
  static const domain = 'pasyar.pages.dev';

  static final terms = Uri.https(domain, '/terms');
  static final privacy = Uri.https(domain, '/privacy');

  /// Opens the loop's preview in the app.
  static Uri loop(String id) => Uri.https(domain, '/l/$id');

  /// Opens the post in the app.
  static Uri post(String id) => Uri.https(domain, '/p/$id');

  /// Opens a rider's profile in the app.
  static Uri rider(String id) => Uri.https(domain, '/r/$id');

  /// Club invite link. Opens JOIN CLUB in the app, or can be pasted in
  /// Me → JOIN WITH A LINK.
  static Uri clubInvite(String code) => Uri.https(domain, '/join/$code');
}

/// What the share sheet sends with a rider's profile link.
String riderShareMessage({
  required String name,
  String? username,
  required Uri link,
}) =>
    'Ride with $name${username == null ? '' : ' (@$username)'} on Pasyar\n'
    '$link';

/// What the share sheet sends with a loop or post link:
/// "Pasyar tayo! Tanay Sunrise Loop · 82 km" and the link on its own line,
/// so chat apps make it tappable and show the preview card.
String shareMessage({
  required String loopName,
  required int distanceM,
  required Uri link,
}) => 'Pasyar tayo! ${loopName.trim()} · ${formatDistance(distanceM)}\n$link';
