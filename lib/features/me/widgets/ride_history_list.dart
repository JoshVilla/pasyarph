import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/repositories/ride_history_repository.dart';
import '../../ride/loop_stats.dart';

/// Rides still postable first (newest first), then the rest.
List<RideSummary> ridesForList(List<RideSummary> rides, DateTime now) => [
  ...rides.where((r) => r.canPost(now)),
  ...rides.where((r) => !r.canPost(now)),
];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Oct 18".
String shortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// "Your rides" on the Me tab: recent rides, with POST on the ones that can
/// still be posted (Prompt 11). Syncs rides saved offline when shown.
class RideHistoryList extends StatefulWidget {
  const RideHistoryList({super.key, this.limit = 20});

  final int limit;

  @override
  State<RideHistoryList> createState() => _RideHistoryListState();
}

class _RideHistoryListState extends State<RideHistoryList> {
  List<RideSummary>? _rides;
  late final RideHistoryRepository _history;

  @override
  void initState() {
    super.initState();
    _history = context.read<RideHistoryRepository>();
    // The Me tab stays alive between visits: reload when a ride is saved
    // (POST LATER), synced or posted.
    _history.revision.addListener(_load);
    _load();
    _history.sync();
  }

  @override
  void dispose() {
    _history.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final rides = await _history.all();
    if (mounted) setState(() => _rides = rides);
  }

  Future<void> _post(RideSummary ride) => context.push(Routes.post(ride.id));

  Future<void> _more(RideSummary ride) async {
    final delete = await showActionSheet<bool>(
      context,
      title: rideName(ride),
      actions: const [
        SheetAction(
          value: true,
          label: 'Delete ride',
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      ],
    );
    if (delete != true || !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this ride?'),
        content: Text(
          ride.posted
              ? "It's removed from your rides and totals. Your post stays."
              : "It's removed from your rides and totals, and can't be "
                    'posted anymore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: PasyarColors.accentDark,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    try {
      await _history.delete(ride);
      messenger.showSnackBar(const SnackBar(content: Text('Ride deleted.')));
    } on RideHistoryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rides = _rides;
    if (rides == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final shown = ridesForList(rides, now).take(widget.limit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text('YOUR RIDES', style: PasyarTextStyles.screenTitle(24)),
        if (shown.isEmpty)
          Text(
            'Rides you finish show up here. Post one within 7 days.',
            style: PasyarTextStyles.body.copyWith(color: PasyarColors.muted),
          ),
        for (final r in shown)
          _RideRow(
            ride: r,
            now: now,
            onPost: r.canPost(now) ? () => _post(r) : null,
            onMore: () => _more(r),
          ),
      ],
    );
  }
}

/// "Talon" (the main stop), or "82 km loop".
String rideName(RideSummary ride) =>
    ride.stop?.name ?? '${formatDistance(ride.loopM)} loop';

class _RideRow extends StatelessWidget {
  const _RideRow({
    required this.ride,
    required this.now,
    required this.onMore,
    this.onPost,
  });

  final RideSummary ride;
  final DateTime now;
  final VoidCallback? onPost;

  /// Delete ride.
  final VoidCallback onMore;

  String get _status {
    if (ride.posted) return 'Posted';
    if (onPost != null) return 'Not posted yet';
    if (!ride.longEnough) return 'Too short to post';
    return 'Not posted';
  }

  @override
  Widget build(BuildContext context) {
    final name = rideName(ride);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
      decoration: BoxDecoration(
        color: PasyarColors.ground,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
      ),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  '${shortDate(ride.endedAt).toUpperCase()} · '
                  '${_status.toUpperCase()}',
                  style: onPost != null
                      ? PasyarTextStyles.overline
                      : PasyarTextStyles.overline.copyWith(
                          color: PasyarColors.muted,
                        ),
                ),
                Text(
                  name,
                  style: PasyarTextStyles.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${formatDistance(ride.riddenM.round())} ridden · '
                  '${formatRideTime(ride.duration.inSeconds)}',
                  style: PasyarTextStyles.label,
                ),
              ],
            ),
          ),
          if (onPost != null)
            SizedBox(
              width: 96,
              child: PrimaryButton(label: 'POST', onPressed: onPost),
            ),
          IconButton(
            onPressed: onMore,
            tooltip: 'More',
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const Icon(
              LucideIcons.ellipsis,
              size: 22,
              color: PasyarColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
