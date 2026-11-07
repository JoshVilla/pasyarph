import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/loop.dart';
import '../../../data/repositories/discovery_repository.dart';
import '../../ride/loop_stats.dart';
import '../../ride/ride_this_loop.dart';
import '../providers/discovery_controller.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});
  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _search = TextEditingController();
  late final DiscoveryController _results;
  String? _opening;

  @override
  void initState() {
    super.initState();
    _results = DiscoveryController(context.read<DiscoveryRepository>());
    unawaited(_results.refresh());
  }

  @override
  void dispose() {
    _results.dispose();
    _search.dispose();
    super.dispose();
  }

  void _reset() {
    _search.clear();
    FocusScope.of(context).unfocus();
    _results.change(const DiscoveryQuery());
  }

  Future<void> _ride(Loop loop) async {
    if (_opening != null) return;
    FocusScope.of(context).unfocus();
    setState(() => _opening = loop.id);
    try {
      await rideThisLoop(context, loopId: loop.id, name: loop.name);
    } finally {
      if (mounted) setState(() => _opening = null);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _results,
    builder: (context, _) {
      final colors = PasyarColors.of(context),
          styles = PasyarTextStyles.of(context);
      final query = _results.query;
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          scrolledUnderElevation: 0,
          elevation: 0,
          toolbarHeight: 64,
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Center(
              child: RoundIconButton.ground(
                icon: LucideIcons.chevronLeft,
                semanticLabel: 'Back',
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go(Routes.feed),
              ),
            ),
          ),
          titleSpacing: 8,
          title: Text(
            'Explore loops',
            style: styles.bodyLarge.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _results.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                Text('Find your next ride', style: styles.bodyLarge),
                const SizedBox(height: 4),
                Text(
                  'Explore public loops shared by riders. Search a destination, province or loop name.',
                  style: styles.label,
                ),
                const SizedBox(height: 20),
                PasyarTextField(
                  label: 'Search routes',
                  hint: 'Try Baguio, Rizal or a waterfall',
                  controller: _search,
                  maxLength: 80,
                  textInputAction: TextInputAction.search,
                  onChanged: _results.searchText,
                  onSubmitted: (_) {
                    FocusScope.of(context).unfocus();
                    unawaited(_results.refresh());
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, box) {
                    final stacked =
                        box.maxWidth < 340 ||
                        MediaQuery.textScalerOf(context).scale(14) > 19;
                    final distance = _filter<DiscoveryDistance>(
                      context,
                      'Distance',
                      query.distance,
                      {
                        for (final value in DiscoveryDistance.values)
                          value: value.label,
                      },
                      (value) =>
                          _results.change(query.copyWith(distance: value)),
                    );
                    final time = _filter<DiscoveryTime>(
                      context,
                      'Ride time',
                      query.time,
                      {
                        for (final value in DiscoveryTime.values)
                          value: value.label,
                      },
                      (value) => _results.change(query.copyWith(time: value)),
                    );
                    return stacked
                        ? Column(spacing: 12, children: [distance, time])
                        : Row(
                            spacing: 12,
                            children: [
                              Expanded(child: distance),
                              Expanded(child: time),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 12),
                _filter<DiscoverySort>(
                  context,
                  'Sort by',
                  query.sort,
                  {
                    for (final value in DiscoverySort.values)
                      value: value.label,
                  },
                  (value) => _results.change(query.copyWith(sort: value)),
                ),
                if (query.filtered)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _reset,
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: const Text('Clear search and filters'),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  query.filtered ? 'Matching routes' : 'Recently shared',
                  style: styles.bodyLarge.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                MotionChange(
                  value: (
                    _results.loading,
                    _results.error,
                    _results.loops.isEmpty,
                  ),
                  duration: PasyarMotion.feedback,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_results.loading)
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        if (_results.loops.isEmpty && _results.error == null)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colors.ground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              spacing: 12,
                              children: [
                                Icon(
                                  LucideIcons.search,
                                  size: 32,
                                  color: colors.muted,
                                ),
                                Text(
                                  query.filtered
                                      ? 'No routes match yet'
                                      : 'No public routes yet',
                                  style: styles.bodyLarge,
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  query.filtered
                                      ? 'Try another destination or widen your distance and ride-time filters.'
                                      : 'Loops shared publicly by riders will appear here.',
                                  style: styles.label,
                                  textAlign: TextAlign.center,
                                ),
                                if (query.filtered)
                                  TextButton(
                                    onPressed: _reset,
                                    child: const Text('Show all routes'),
                                  ),
                              ],
                            ),
                          ),
                        for (final loop in _results.loops)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RouteCard(
                              loop: loop,
                              opening: _opening == loop.id,
                              onTap: _opening == null
                                  ? () => _ride(loop)
                                  : null,
                            ),
                          ),
                        if (_results.error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              spacing: 8,
                              children: [
                                Text(
                                  _results.error!,
                                  style: styles.label,
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: () => _results.loops.isEmpty
                                      ? _results.refresh()
                                      : _results.loadMore(),
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          )
                        else if (_results.hasMore)
                          SecondaryButton(
                            label: 'Load more routes',
                            loading: _results.loadingMore,
                            onPressed: _results.loadingMore
                                ? null
                                : _results.loadMore,
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _filter<T>(
    BuildContext context,
    String label,
    T selected,
    Map<T, String> choices,
    ValueChanged<T> changed,
  ) => DropdownButtonFormField<T>(
    key: ValueKey((label, selected)),
    initialValue: selected,
    isExpanded: true,
    style: PasyarTextStyles.of(context).body,
    dropdownColor: PasyarColors.of(context).card,
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: PasyarColors.of(context).card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    items: [
      for (final entry in choices.entries)
        DropdownMenuItem(
          value: entry.key,
          child: Text(
            entry.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: (value) {
      if (value != null) changed(value);
    },
  );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.loop, required this.opening, this.onTap});
  final Loop loop;
  final bool opening;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final colors = PasyarColors.of(context),
        styles = PasyarTextStyles.of(context);
    final location = [?loop.mainStop?.name, ?loop.province].join(' · ');
    return Semantics(
      button: true,
      enabled: onTap != null,
      label:
          'Preview ${loop.name}, ${formatDistance(loop.distanceM)}, ${formatRideTime(loop.durationS)}',
      excludeSemantics: true,
      child: Material(
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Row(
                  spacing: 12,
                  children: [
                    RouteThumbnail(
                      route: loop.sharedRoute ?? const [],
                      width: 72,
                      height: 72,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: [
                          Text(
                            loop.name,
                            style: styles.bodyLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (location.isNotEmpty)
                            Text(
                              location,
                              style: styles.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 1),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatDistance(loop.distanceM),
                      style: styles.bodyStrong,
                    ),
                    Text(
                      formatRideTime(loop.durationS),
                      style: styles.bodySmall,
                    ),
                    if (loop.curvinessScore case final score?)
                      Text(
                        'Curvy: ${curvyLevel(score).label}',
                        style: styles.label,
                      ),
                  ],
                ),
                Row(
                  spacing: 8,
                  children: [
                    if (opening)
                      const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(LucideIcons.route, size: 16, color: colors.accent),
                    Expanded(
                      child: Text(
                        opening
                            ? 'Preparing your route…'
                            : 'Preview from your location',
                        style: styles.bodySmall.copyWith(color: colors.accent),
                      ),
                    ),
                    Icon(
                      LucideIcons.arrowUpRight,
                      size: 18,
                      color: colors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
