import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/loop.dart';
import '../../../data/repositories/loop_repository.dart';
import '../../ride/loop_stats.dart';
import '../../ride/ride_this_loop.dart';

/// "Public", "Group", "Private" as the Create sheet labels them.
String visibilityLabel(LoopVisibility v) => switch (v) {
  LoopVisibility.public => 'Public',
  LoopVisibility.club => 'Group',
  LoopVisibility.private => 'Private',
};

/// "Your loops" on the Me tab: loops the rider saved in Create (and any
/// other loops they own). Tapping one rides it from where they are.
/// Reloads after every save.
class MyLoopsList extends StatefulWidget {
  const MyLoopsList({super.key});

  @override
  State<MyLoopsList> createState() => _MyLoopsListState();
}

class _MyLoopsListState extends State<MyLoopsList> {
  late final LoopRepository _loops = context.read<LoopRepository>();
  List<Loop>? _mine;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loops.revision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _loops.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final mine = await _loops.mine();
      if (!mounted) return;
      setState(() {
        _mine = mine;
        _error = null;
      });
    } on LoopException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    final empty = PasyarTextStyles.body.copyWith(color: PasyarColors.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        Text('YOUR LOOPS', style: PasyarTextStyles.screenTitle(24)),
        if (mine == null && _error != null)
          Text(_error!, style: empty)
        else if (mine != null && mine.isEmpty)
          Text('Loops you make in Create show up here.', style: empty),
        for (final loop in mine ?? const <Loop>[])
          _LoopRow(
            loop: loop,
            onTap: () =>
                rideThisLoop(context, loopId: loop.id, name: loop.name),
          ),
      ],
    );
  }
}

class _LoopRow extends StatelessWidget {
  const _LoopRow({required this.loop, required this.onTap});

  final Loop loop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Loops under 1.8 km have nothing left after the home privacy trim.
    final rideable = loop.sharedRoute != null;
    return Semantics(
      button: rideable,
      child: Material(
        color: PasyarColors.ground,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: rideable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        '${visibilityLabel(loop.visibility)} · '
                                '${loop.source == LoopSource.custom ? 'Made by you' : 'Generated'}'
                            .toUpperCase(),
                        style: PasyarTextStyles.overline,
                      ),
                      Text(
                        loop.name,
                        style: PasyarTextStyles.bodyLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${formatDistance(loop.distanceM)} · '
                        '${formatRideTime(loop.durationS)}',
                        style: PasyarTextStyles.label,
                      ),
                    ],
                  ),
                ),
                if (rideable)
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 22,
                    color: PasyarColors.muted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
