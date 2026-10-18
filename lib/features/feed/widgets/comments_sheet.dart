import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/models/post.dart';
import '../../../data/repositories/feed_repository.dart';
import '../../../data/repositories/social_repository.dart';
import '../feed_format.dart';
import '../providers/comments_controller.dart';

/// Opens a post's comments as a tall bottom sheet. Resolves with the
/// controller's final state so the feed card can update its count and
/// preview. No mockup: built from DESIGN.md components (bottom sheet,
/// comment bubbles as on the feed card, a rounded input like the composer).
Future<CommentsController> showCommentsSheet(
  BuildContext context,
  FeedPost post, {
  DateTime Function() clock = DateTime.now,
}) async {
  final controller = CommentsController(
    postId: post.id,
    social: context.read<SocialRepository>(),
    count: post.commentCount,
  )..load();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsSheet(controller: controller, clock: clock),
  );
  return controller;
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.controller,
    this.clock = DateTime.now,
  });

  final CommentsController controller;
  final DateTime Function() clock;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  CommentsController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _c.loadMore();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (await _c.send(_input.text)) {
      _input.clear();
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Future<void> _confirmDelete(Comment c) async {
    final delete = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BottomSheetPanel(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewPaddingOf(context).bottom + 20,
        ),
        children: [
          Text('DELETE COMMENT?', style: PasyarTextStyles.screenTitle(30)),
          PrimaryButton(
            label: 'DELETE',
            onPressed: () => Navigator.pop(context, true),
          ),
          SecondaryButton(
            label: 'KEEP',
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (delete == true) await _c.delete(c);
  }

  @override
  Widget build(BuildContext context) {
    final moving = context.watch<LocationProvider>().isMoving;
    final feed = context.read<FeedRepository>();
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final now = widget.clock();
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            decoration: const BoxDecoration(
              color: PasyarColors.card,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(PasyarRadius.sheet),
              ),
              boxShadow: PasyarShadows.sheet,
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const DragHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'COMMENTS',
                          style: PasyarTextStyles.screenTitle(28),
                        ),
                      ),
                      Text(
                        plural(_c.count, 'comment'),
                        style: PasyarTextStyles.label,
                      ),
                      RoundIconButton.ground(
                        icon: LucideIcons.x,
                        iconSize: 20,
                        semanticLabel: 'Close',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _list(now, feed)),
                const Divider(height: 1, color: PasyarColors.line),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    10 + (insets > 0 ? insets : bottom),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 6,
                    children: [
                      if (_c.error != null || moving)
                        Text(
                          moving
                              ? 'Stop riding to write a comment.'
                              : _c.error!,
                          style: PasyarTextStyles.label.copyWith(
                            color: PasyarColors.accentDark,
                          ),
                        ),
                      _InputRow(
                        controller: _input,
                        enabled: !moving,
                        sending: _c.sending,
                        onSend: _send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _list(DateTime now, FeedRepository feed) {
    if (_c.loading) {
      return const Center(
        child: CircularProgressIndicator(color: PasyarColors.accent),
      );
    }
    final comments = _c.comments;
    if (comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(PasyarSpacing.sheet),
          child: Text(
            'No comments yet. Ask about the road, or say how the ride was.',
            textAlign: TextAlign.center,
            style: PasyarTextStyles.body.copyWith(color: PasyarColors.muted),
          ),
        ),
      );
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: comments.length + (_c.loadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i == comments.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: PasyarColors.accent),
            ),
          );
        }
        final c = comments[i];
        return _CommentTile(
          comment: c,
          when: timeAgo(c.createdAt, now),
          avatar: c.author?.avatarUrl == null
              ? null
              : feed.avatar(c.author!.avatarUrl!),
          onDelete: _c.isMine(c) ? () => _confirmDelete(c) : null,
        );
      },
    );
  }
}

/// Avatar, `ground` bubble with name and text, then time and Delete.
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.when,
    this.avatar,
    this.onDelete,
  });

  final Comment comment;
  final String when;
  final ImageProvider? avatar;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final name = comment.author?.displayName ?? 'A rider';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Avatar(name: name, size: 32, image: avatar),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: PasyarColors.ground,
                  borderRadius: BorderRadius.circular(PasyarRadius.choiceCard),
                ),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$name\n',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: comment.body),
                    ],
                  ),
                  style: PasyarTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ),
              // Same height on every comment; Delete's 44 px touch area
              // overflows it.
              SizedBox(
                height: 24,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Text(when, style: PasyarTextStyles.label),
                    ),
                    if (onDelete != null)
                      SizedBox(
                        width: 60,
                        child: OverflowBox(
                          maxHeight: PasyarSpacing.minTouch,
                          maxWidth: 80,
                          child: TextButton(
                            onPressed: onDelete,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(
                                44,
                                PasyarSpacing.minTouch,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              foregroundColor: PasyarColors.muted,
                              textStyle: PasyarTextStyles.label.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: const Text('Delete'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rounded "Write a comment…" field (like the feed composer) and a 44 px
/// orange send button.
class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide(color: color, width: 1.5),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 10,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            readOnly: !enabled,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            style: PasyarTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Write a comment…',
              hintStyle: PasyarTextStyles.body.copyWith(
                color: PasyarColors.muted,
              ),
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 11,
              ),
              border: border(PasyarColors.line),
              enabledBorder: border(PasyarColors.line),
              focusedBorder: border(PasyarColors.ink),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final ready =
                enabled && !sending && controller.text.trim().isNotEmpty;
            return Semantics(
              button: true,
              enabled: ready,
              label: 'Send comment',
              excludeSemantics: true,
              child: Material(
                color: ready
                    ? PasyarColors.accent
                    : PasyarColors.accent.withValues(alpha: 0.4),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: ready ? onSend : null,
                  child: SizedBox.square(
                    dimension: PasyarSpacing.minTouch,
                    child: sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: PasyarColors.card,
                            ),
                          )
                        : const Icon(
                            LucideIcons.sendHorizontal,
                            size: 20,
                            color: PasyarColors.card,
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
