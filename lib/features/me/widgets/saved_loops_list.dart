import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/links.dart';
import '../../../core/share.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/loop.dart';
import '../../../data/repositories/me_repository.dart';
import '../../ride/ride_this_loop.dart';
import 'loop_row.dart';

enum _SavedAction { share, remove }

/// "Saved" on the Me tab: loops saved from posts (⋯ → Save loop), newest
/// first. Tap to ride; ⋯ to share or remove. Reloads when one is saved.
class SavedLoopsList extends StatefulWidget {
  const SavedLoopsList({super.key});

  @override
  State<SavedLoopsList> createState() => _SavedLoopsListState();
}

class _SavedLoopsListState extends State<SavedLoopsList> {
  late final MeRepository _me = context.read<MeRepository>();
  List<Loop>? _saved;
  String? _error;

  @override
  void initState() {
    super.initState();
    _me.savedRevision.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _me.savedRevision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final saved = await _me.savedLoops();
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _error = null;
      });
    } on MeException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _more(Loop loop) async {
    final action = await showActionSheet<_SavedAction>(
      context,
      title: loop.name,
      actions: [
        SheetAction(
          value: _SavedAction.share,
          label: 'Share link',
          icon: LucideIcons.share2,
          enabled: loop.visibility != LoopVisibility.private,
        ),
        const SheetAction(
          value: _SavedAction.remove,
          label: 'Remove from saved',
          icon: LucideIcons.bookmarkMinus,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _SavedAction.share:
        await context.read<Sharer>().share(
          shareMessage(
            loopName: loop.name,
            distanceM: loop.distanceM,
            link: AppLinks.loop(loop.id),
          ),
          subject: loop.name,
        );
      case _SavedAction.remove:
        try {
          await _me.unsaveLoop(loop.id);
        } on MeException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(e.message)));
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    final empty = PasyarTextStyles.body.copyWith(color: PasyarColors.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        if (saved == null && _error != null)
          Text(_error!, style: empty)
        else if (saved != null && saved.isEmpty)
          Text(
            'Save loops from the feed (⋯ on a post) to ride them later.',
            style: empty,
          ),
        for (final loop in saved ?? const <Loop>[])
          LoopRow(
            loop: loop,
            detail: loop.province,
            onTap: () =>
                rideThisLoop(context, loopId: loop.id, name: loop.name),
            onMore: () => _more(loop),
          ),
      ],
    );
  }
}
