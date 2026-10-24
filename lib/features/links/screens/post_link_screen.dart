import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/link_preview.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/link_repository.dart';
import '../../feed/providers/feed_provider.dart';
import '../../feed/widgets/feed_items.dart';
import '../link_messages.dart';
import '../widgets/link_scaffold.dart';

/// Opened from a post link (https://pasyar.pages.dev/p/id): the post card,
/// as in the feed, once the rider may see it. Expects a [FeedProvider] for
/// [FeedScope.post] above it.
class PostLinkScreen extends StatefulWidget {
  const PostLinkScreen({
    super.key,
    required this.postId,
    this.clock = DateTime.now,
  });

  final String postId;
  final DateTime Function() clock;

  @override
  State<PostLinkScreen> createState() => _PostLinkScreenState();
}

class _PostLinkScreenState extends State<PostLinkScreen> {
  late final LinkRepository _links = context.read<LinkRepository>();
  late final FeedProvider _feed = context.read<FeedProvider>();

  LinkPreview? _link;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    setState(() => _error = null);
    try {
      final link = await _links.preview(LinkKind.post, widget.postId);
      if (!mounted) return;
      setState(() => _link = link);
      if (link.status == LinkStatus.ok) _feed.start();
    } on LinkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    if (_error != null) {
      return LinkScaffold.error(
        title: 'OPENING POST',
        error: _error!,
        onRetry: _open,
      );
    }
    if (link == null) return const LinkScaffold.loading(title: 'OPENING POST');
    final blocked = blockedLinkMessage(link, what: 'POST');
    if (blocked != null) return LinkScaffold.blocked(blocked);

    final feed = context.watch<FeedProvider>();
    final items = <Widget>[
      _Header(
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.feed),
      ),
      ...feedPostItems(
        feed,
        now: widget.clock(),
        actions: feedCardActions(context, feed, clock: widget.clock),
        repo: context.read<FeedRepository>(),
        emptyText: 'This post may have been deleted.',
      ),
    ];
    return Scaffold(
      backgroundColor: PasyarColors.line,
      body: RefreshIndicator(
        color: PasyarColors.accent,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: feed.refresh,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => items[i],
        ),
      ),
    );
  }
}

/// Back button and "RIDE" on white, like the top of a rider's profile.
class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: PasyarColors.card,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          PasyarSpacing.screen,
          top + 8,
          PasyarSpacing.screen,
          12,
        ),
        child: Row(
          spacing: 12,
          children: [
            RoundIconButton.ground(
              icon: LucideIcons.chevronLeft,
              semanticLabel: 'Back',
              onPressed: onBack,
            ),
            Semantics(
              header: true,
              child: Text('RIDE', style: PasyarTextStyles.screenTitle(32)),
            ),
          ],
        ),
      ),
    );
  }
}
