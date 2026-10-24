import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/moderation_repository.dart';
import '../widgets/titled_page.dart';

/// Settings → Blocked riders: who the rider blocked, with UNBLOCK.
class BlockedRidersScreen extends StatefulWidget {
  const BlockedRidersScreen({super.key});

  @override
  State<BlockedRidersScreen> createState() => _BlockedRidersScreenState();
}

class _BlockedRidersScreenState extends State<BlockedRidersScreen> {
  late final ModerationRepository _moderation = context
      .read<ModerationRepository>();
  List<ProfileSummary>? _riders;
  String? _error;
  final _unblocking = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final riders = await _moderation.blocked();
      if (!mounted) return;
      setState(() {
        _riders = riders;
        _error = null;
      });
    } on ModerationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _unblock(ProfileSummary rider) async {
    setState(() => _unblocking.add(rider.id));
    try {
      await _moderation.unblock(rider.id);
      if (!mounted) return;
      setState(() => _riders?.removeWhere((r) => r.id == rider.id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${rider.displayName ?? 'The rider'} is unblocked.'),
          ),
        );
    } on ModerationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _unblocking.remove(rider.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final riders = _riders;
    final feed = context.read<FeedRepository>();
    return TitledPage(
      title: 'BLOCKED RIDERS',
      subtitle:
          "You don't see their rides, loops or comments. They aren't told.",
      onRefresh: _load,
      children: [
        if (riders == null)
          _error != null ? PageMessage(_error!) : const PageLoading()
        else if (riders.isEmpty)
          const PageMessage("You haven't blocked anyone.")
        else
          for (final r in riders)
            SizedBox(
              height: 64,
              child: Row(
                spacing: 12,
                children: [
                  Avatar(
                    name: r.displayName ?? 'A rider',
                    image: r.avatarUrl == null ? null : feed.avatar(r.avatarUrl!),
                    size: 40,
                  ),
                  Expanded(
                    child: Text(
                      r.displayName ?? 'A rider',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PasyarTextStyles.bodyStrong,
                    ),
                  ),
                  TextButton(
                    onPressed: _unblocking.contains(r.id)
                        ? null
                        : () => _unblock(r),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(88, 48),
                      foregroundColor: PasyarColors.accentDark,
                      textStyle: PasyarTextStyles.buttonSecondary.copyWith(
                        fontSize: 16,
                      ),
                    ),
                    child: const Text('UNBLOCK'),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
