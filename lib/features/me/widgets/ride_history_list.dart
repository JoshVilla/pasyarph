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
              foregroundColor: PasyarColors.of(context).accentDark,
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Ride history',
                style: PasyarTextStyles.of(
                  context,
                ).bodyLarge.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${shown.length} ${shown.length == 1 ? 'ride' : 'rides'}',
              style: PasyarTextStyles.of(context).label,
            ),
          ],
        ),
        if (shown.isEmpty)
          Text(
            'Rides you finish show up here. Post one within 7 days.',
            style: PasyarTextStyles.of(
              context,
            ).body.copyWith(color: PasyarColors.of(context).muted),
          ),
        for (final r in shown)
          _RideRow(
            ride: r,

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
  const _RideRow({required this.ride, required this.onMore, this.onPost});

  final RideSummary ride;

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
    final ready = onPost != null;
    final route = ride.preview.isNotEmpty ? ride.preview : ride.route;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PasyarColors.of(context).ground,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
        border: Border.all(
          color: ready
              ? PasyarColors.of(context).accentTint
              : PasyarColors.of(context).line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(ride.endedAt.toLocal()),
                      style: PasyarTextStyles.of(context).label,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: ready
                            ? PasyarColors.of(context).accentTint
                            : PasyarColors.of(context).card,
                        borderRadius: BorderRadius.circular(PasyarRadius.pill),
                      ),
                      child: Text(
                        _status.toUpperCase(),
                        style: PasyarTextStyles.of(context).overline.copyWith(
                          fontSize: 12,
                          color: ready
                              ? PasyarColors.of(context).accentDark
                              : PasyarColors.of(context).muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMore,
                tooltip: 'More',
                constraints: const BoxConstraints.tightFor(
                  width: 48,
                  height: 48,
                ),
                icon: Icon(
                  LucideIcons.ellipsis,
                  size: 22,
                  color: PasyarColors.of(context).muted,
                ),
              ),
            ],
          ),
          Row(
            spacing: 12,
            children: [
              if (route != null && route.length > 1)
                RouteThumbnail(route: route, width: 60, height: 60)
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: PasyarColors.of(context).card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.route,
                    color: PasyarColors.of(context).accent,
                    size: 26,
                  ),
                ),
              Expanded(
                child: Text(
                  rideName(ride),
                  style: PasyarTextStyles.of(context).bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Divider(height: 1, color: PasyarColors.of(context).line),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _stat(
                    context,
                    formatDistance(ride.riddenM.round()),
                    'Distance ridden',
                  ),
                  _stat(
                    context,
                    formatRideTime(ride.duration.inSeconds),
                    'Ride time',
                  ),
                ],
              ),
              if (ready)
                FilledButton.icon(
                  onPressed: onPost,
                  style: FilledButton.styleFrom(
                    backgroundColor: PasyarColors.of(context).accent,
                    foregroundColor: PasyarColors.of(context).onAccent,
                    minimumSize: const Size(96, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('POST'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: PasyarTextStyles.of(context).statValueSmall),
      Text(label, style: PasyarTextStyles.of(context).label),
    ],
  );
}
