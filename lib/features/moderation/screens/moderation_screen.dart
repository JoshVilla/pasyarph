import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/repositories/moderation_repository.dart';
import '../../feed/feed_format.dart';
import '../widgets/titled_page.dart';

/// "Spam or selling ×2", most common first, at most [max] lines.
List<String> summarizeReasons(List<String> reasons, {int max = 3}) {
  final counts = <String, int>{};
  for (final r in reasons) {
    counts[r] = (counts[r] ?? 0) + 1;
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in sorted.take(max))
      e.value == 1 ? e.key : '${e.key} ×${e.value}',
    if (sorted.length > max) '+ ${sorted.length - max} more',
  ];
}

String _targetLabel(ReportTarget t) => switch (t) {
  ReportTarget.post => 'POST',
  ReportTarget.comment => 'COMMENT',
  ReportTarget.loop => 'LOOP',
  ReportTarget.user => 'RIDER',
};

/// Settings → Moderation (admins only): open reports, most reported first.
/// HIDE removes it for everyone but its author; DISMISS keeps it. Both
/// close its reports. A hidden item can be shown again.
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key, this.clock = DateTime.now});

  final DateTime Function() clock;

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  late final ModerationRepository _moderation = context
      .read<ModerationRepository>();
  List<ReportedItem>? _items;
  String? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _moderation.reportQueue();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } on ModerationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _act(ReportedItem item, ModerationAction action) async {
    setState(() => _busy.add(item.targetId));
    try {
      await _moderation.moderate(item.targetType, item.targetId, action);
      if (!mounted) return;
      setState(() {
        final items = _items!;
        final i = items.indexWhere((x) => x.targetId == item.targetId);
        if (i < 0) return;
        switch (action) {
          // Its reports are closed: it leaves the queue.
          case ModerationAction.hide:
          case ModerationAction.dismiss:
            items.removeAt(i);
          case ModerationAction.unhide:
            items[i] = item.copyWith(isHidden: false);
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(switch (action) {
              ModerationAction.hide => 'Hidden. Reports closed.',
              ModerationAction.unhide => 'Shown again.',
              ModerationAction.dismiss => 'Kept. Reports closed.',
            }),
          ),
        );
    } on ModerationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy.remove(item.targetId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final now = widget.clock();
    return TitledPage(
      title: 'MODERATION',
      subtitle: 'Open reports, most reported first.',
      onRefresh: _load,
      children: [
        if (items == null)
          _error != null ? PageMessage(_error!) : const PageLoading()
        else if (items.isEmpty)
          const PageMessage('No open reports. Nice.')
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportCard(
                item: item,
                now: now,
                busy: _busy.contains(item.targetId),
                onAction: (a) => _act(item, a),
              ),
            ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.item,
    required this.now,
    required this.busy,
    required this.onAction,
  });

  final ReportedItem item;
  final DateTime now;
  final bool busy;
  final ValueChanged<ModerationAction> onAction;

  @override
  Widget build(BuildContext context) {
    final n = item.reportCount;
    final overline = [
      _targetLabel(item.targetType),
      '$n ${n == 1 ? 'REPORT' : 'REPORTS'}',
      if (item.isHidden) 'HIDDEN',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PasyarColors.ground,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Text(overline, style: PasyarTextStyles.overline),
          Text(
            item.preview ?? 'Deleted since it was reported.',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: item.preview == null
                ? PasyarTextStyles.body.copyWith(color: PasyarColors.muted)
                : PasyarTextStyles.bodyLarge,
          ),
          Text(
            [
              if (item.authorName != null) 'By ${item.authorName}',
              'Last reported ${timeAgo(item.lastReportedAt, now).toLowerCase()}',
            ].join(' · '),
            style: PasyarTextStyles.label,
          ),
          for (final r in summarizeReasons(item.reasons))
            Text('• $r', style: PasyarTextStyles.bodySmall),
          const SizedBox(height: 4),
          Row(
            spacing: PasyarSpacing.buttonGap,
            children: [
              Expanded(
                child: item.isHidden
                    ? SecondaryButton(
                        label: 'UNHIDE',
                        onPressed: busy
                            ? null
                            : () => onAction(ModerationAction.unhide),
                      )
                    : PrimaryButton(
                        label: 'HIDE',
                        loading: busy,
                        onPressed: busy
                            ? null
                            : () => onAction(ModerationAction.hide),
                      ),
              ),
              Expanded(
                child: SecondaryButton(
                  label: 'DISMISS',
                  onPressed: busy
                      ? null
                      : () => onAction(ModerationAction.dismiss),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
