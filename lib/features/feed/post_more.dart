import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/widgets.dart';
import '../../data/models/enums.dart';
import '../../data/models/post.dart';
import '../../data/repositories/me_repository.dart';
import '../../data/repositories/moderation_repository.dart';
import '../../data/repositories/social_repository.dart';
import '../moderation/widgets/report_sheet.dart';

enum _PostAction { save, unsave, share, report, blockItem, block }

/// A post's ⋯ menu: save its loop to ride later (Me → Saved), share it,
/// report it, block just this post, or block its rider. [onBlocked] runs
/// after blocking either (the feed reloads without them).
Future<void> showPostMore(
  BuildContext context,
  FeedPost post, {
  required VoidCallback onShare,
  VoidCallback? onBlocked,
}) async {
  final me = context.read<MeRepository>();
  final mine = post.author.id == context.read<SocialRepository>().userId;
  final name = post.author.displayName ?? 'this rider';
  void snack(String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // Saving twice is harmless, so a slow or failed check just offers Save.
  var saved = false;
  final loop = post.loop;
  if (!mine && loop != null) {
    try {
      saved = await me.isSaved(loop.id).timeout(const Duration(seconds: 3));
    } on Exception {
      saved = false;
    }
  }
  if (!context.mounted) return;

  final action = await showActionSheet<_PostAction>(
    context,
    title: loop?.name ?? "${post.author.displayName ?? 'A rider'}'s post",
    actions: [
      if (!mine && loop != null)
        saved
            ? const SheetAction(
                value: _PostAction.unsave,
                label: 'Remove from saved loops',
                icon: LucideIcons.bookmarkMinus,
              )
            : const SheetAction(
                value: _PostAction.save,
                label: 'Save loop to ride later',
                icon: LucideIcons.bookmark,
              ),
      const SheetAction(
        value: _PostAction.share,
        label: 'Share',
        icon: LucideIcons.share2,
      ),
      if (!mine) ...[
        SheetAction(
          value: _PostAction.report,
          label: post.isLoopOnly ? 'Report loop' : 'Report post',
          icon: LucideIcons.flag,
        ),
        SheetAction(
          value: _PostAction.blockItem,
          label: post.isLoopOnly ? 'Block this loop' : 'Block this post',
          icon: LucideIcons.eyeOff,
          destructive: true,
        ),
        SheetAction(
          value: _PostAction.block,
          label: 'Block $name',
          icon: LucideIcons.ban,
          destructive: true,
        ),
      ],
    ],
  );
  switch (action) {
    case null:
      return;
    case _PostAction.save:
      try {
        await me.saveLoop(loop!.id);
        snack('Saved. Find it under Me → Saved.');
      } on MeException catch (e) {
        snack(e.message);
      }
    case _PostAction.unsave:
      try {
        await me.unsaveLoop(loop!.id);
        snack('Removed from your saved loops.');
      } on MeException catch (e) {
        snack(e.message);
      }
    case _PostAction.share:
      onShare();
    case _PostAction.report:
      if (!context.mounted) return;
      final result = await showReportSheet(
        context,
        ReportSubject(
          // A loop shared without a post is reported as the loop.
          target: post.isLoopOnly ? ReportTarget.loop : ReportTarget.post,
          id: post.isLoopOnly ? loop!.id : post.id,
          what: post.isLoopOnly ? 'loop' : 'post',
          authorId: post.author.id,
          authorName: post.author.displayName,
        ),
      );
      if (result == null) return;
      snack(
        result.blocked
            ? 'Thanks for reporting. $name is blocked.'
            : 'Thanks for reporting. A moderator will take a look.',
      );
      if (result.blocked) onBlocked?.call();
    case _PostAction.block:
      if (!context.mounted) return;
      final blocked = await confirmBlock(
        context,
        userId: post.author.id,
        name: name,
      );
      if (blocked) onBlocked?.call();
    case _PostAction.blockItem:
      if (!context.mounted) return;
      await _blockItem(context, post, onChanged: onBlocked);
  }
}

/// Blocks just this post (or shared loop) for the rider, with UNDO.
Future<void> _blockItem(
  BuildContext context,
  FeedPost post, {
  VoidCallback? onChanged,
}) async {
  final moderation = context.read<ModerationRepository>();
  final messenger = ScaffoldMessenger.of(context);
  final (item, id, what) = post.isLoopOnly
      ? (BlockedItem.loop, post.loop!.id, 'Loop')
      : (BlockedItem.post, post.id, 'Post');
  void show(String text, {SnackBarAction? action}) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
  try {
    await moderation.blockItem(item, id);
  } on ModerationException catch (e) {
    return show(e.message);
  }
  onChanged?.call();
  show(
    "$what blocked. You won't see it again.",
    action: SnackBarAction(
      label: 'UNDO',
      onPressed: () async {
        try {
          await moderation.unblockItem(item, id);
          onChanged?.call();
        } on ModerationException catch (e) {
          show(e.message);
        }
      },
    ),
  );
}
