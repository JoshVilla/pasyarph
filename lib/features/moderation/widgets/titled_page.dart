import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';

/// White page with a back button and a big title, like Settings: Blocked
/// riders and Moderation. [children] scroll; pull to refresh with
/// [onRefresh].
class TitledPage extends StatelessWidget {
  const TitledPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        PasyarSpacing.sheet,
        top + 8,
        PasyarSpacing.sheet,
        36,
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: RoundIconButton.ground(
            icon: LucideIcons.chevronLeft,
            semanticLabel: 'Back',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(Routes.me),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            title,
            style: PasyarTextStyles.of(context).screenTitle(36),
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle!,
              style: PasyarTextStyles.of(
                context,
              ).body.copyWith(color: PasyarColors.of(context).muted),
            ),
          ),
        const SizedBox(height: 20),
        ...children,
      ],
    );
    return Scaffold(
      backgroundColor: PasyarColors.of(context).background,
      body: onRefresh == null
          ? list
          : RefreshIndicator(
              color: PasyarColors.of(context).accent,
              edgeOffset: top,
              onRefresh: onRefresh!,
              child: list,
            ),
    );
  }
}

/// Muted text in the middle of an empty page (or an error).
class PageMessage extends StatelessWidget {
  const PageMessage(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: PasyarTextStyles.of(
          context,
        ).body.copyWith(color: PasyarColors.of(context).muted),
      ),
    );
  }
}

/// Spinner while a page loads.
class PageLoading extends StatelessWidget {
  const PageLoading({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.all(32),
    child: Center(
      child: CircularProgressIndicator(color: PasyarColors.of(context).accent),
    ),
  );
}
