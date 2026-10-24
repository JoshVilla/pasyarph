import '../../data/models/post.dart';
import '../../data/repositories/me_repository.dart';
import '../../data/repositories/ride_history_repository.dart';

/// The server's totals plus rides still waiting to sync (saved offline), so
/// a ride shows up in the header as soon as it ends.
RiderTotals withUnsyncedRides(RiderTotals server, Iterable<RideSummary> rides) {
  final pending = rides.where((r) => !r.synced && r.id.isNotEmpty);
  return server.plus(
    riddenM: pending.fold(0, (sum, r) => sum + r.riddenM.round()),
    loopsRidden: pending.where((r) => r.longEnough).length,
  );
}

/// "0", "8.4", "128", "1,234" (km, for the header).
String formatTotalKm(int meters) {
  final km = meters / 1000;
  if (km > 0 && km < 10) return km.toStringAsFixed(1);
  final whole = km.round().toString();
  final groups = <String>[];
  for (var end = whole.length; end > 0; end -= 3) {
    groups.insert(0, whole.substring(end - 3 < 0 ? 0 : end - 3, end));
  }
  return groups.join(',');
}

/// The rider's posts (not loops shared without a post), for the grid.
List<FeedPost> postsOnly(Iterable<FeedPost> items) => [
  for (final p in items)
    if (!p.isLoopOnly) p,
];
