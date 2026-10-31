import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/router.dart';
import '../../core/widgets/widgets.dart';
import '../../data/repositories/ride_history_repository.dart';
import '../me/widgets/ride_history_list.dart';

/// Rides in the picker; older postable ones are still on the Me tab.
const _maxRides = 5;

/// Feed's "add photos" button: straight to the post screen for the only ride
/// that can be posted, a picker for several, or why there's nothing to post.
Future<void> postARide(
  BuildContext context, {
  DateTime Function()? clock,
}) async {
  final now = (clock ?? DateTime.now)();
  final all = await context.read<RideHistoryRepository>().all();
  final rides = all.where((r) => r.canPost(now)).take(_maxRides).toList();
  if (!context.mounted) return;

  if (rides.isEmpty) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'No rides to post yet. Finish a ride with Pasyar, then post it '
            'within 7 days.',
          ),
          action: SnackBarAction(
            label: 'RIDE',
            onPressed: () => context.go(Routes.ride),
          ),
        ),
      );
    return;
  }

  final id = rides.length == 1
      ? rides.single.id
      : await showActionSheet<String>(
          context,
          title: 'Which ride?',
          actions: [
            for (final r in rides)
              SheetAction(
                value: r.id,
                label: '${rideName(r)} · ${shortDate(r.endedAt)}',
                icon: LucideIcons.image,
              ),
          ],
        );
  if (id != null && context.mounted) await context.push(Routes.post(id));
}
