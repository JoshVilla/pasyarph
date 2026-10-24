import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/widgets.dart';
import '../../data/models/post.dart';
import '../../data/repositories/me_repository.dart';
import '../../data/repositories/social_repository.dart';

enum _PostAction { save, unsave, share, report }

/// A post's ⋯ menu: save its loop to ride later (Me → Saved), share it,
/// and report (Prompt 20).
Future<void> showPostMore(
  BuildContext context,
  FeedPost post, {
  required VoidCallback onShare,
}) async {
  final me = context.read<MeRepository>();
  final mine = post.loop.ownerId == context.read<SocialRepository>().userId;
  void snack(String text) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // Saving twice is harmless, so a slow or failed check just offers Save.
  var saved = false;
  if (!mine) {
    try {
      saved = await me
          .isSaved(post.loop.id)
          .timeout(const Duration(seconds: 3));
    } on Exception {
      saved = false;
    }
  }
  if (!context.mounted) return;

  final action = await showActionSheet<_PostAction>(
    context,
    title: post.loop.name,
    actions: [
      if (!mine)
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
      if (!mine)
        const SheetAction(
          value: _PostAction.report,
          label: 'Report',
          icon: LucideIcons.flag,
        ),
    ],
  );
  switch (action) {
    case null:
      return;
    case _PostAction.save:
      try {
        await me.saveLoop(post.loop.id);
        snack('Saved. Find it under Me → Saved.');
      } on MeException catch (e) {
        snack(e.message);
      }
    case _PostAction.unsave:
      try {
        await me.unsaveLoop(post.loop.id);
        snack('Removed from your saved loops.');
      } on MeException catch (e) {
        snack(e.message);
      }
    case _PostAction.share:
      onShare();
    case _PostAction.report:
      snack('Reporting posts is coming soon.');
  }
}
