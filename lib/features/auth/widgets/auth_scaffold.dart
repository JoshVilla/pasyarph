import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Layout shared by the white auth screens (Log in, Register, Forgot
/// password, Check your email, Set new password), from mockups 08 and 09:
/// 56 px top, 20 px sides, 36 px bottom; back button, title, subtitle, a
/// scrolling form, and the main button pinned at the bottom.
///
/// The form scrolls and the bottom actions sit above the keyboard, so the
/// keyboard never covers the focused field or the main button.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.bottom,
    this.subtitle,
    this.onBack,
    this.leading,
    this.gap = 20,
    this.top = 56,
    this.titleSize = 36,
    this.titleHeight = 1.2,
    this.subtitleGap = 4,
    this.subtitleHeight = 1.2,
    this.bottomTrim,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  /// Shown above the title instead of the back button (e.g. a mail icon).
  final Widget? leading;
  final List<Widget> children;

  /// Main button and footer link.
  final List<Widget> bottom;
  final double gap;

  /// Minimum top padding (56 on auth screens, 60 on onboarding).
  final double top;
  final double titleSize;
  final double titleHeight;
  final double subtitleGap;
  final double subtitleHeight;

  /// Taken off the 36 px bottom padding when the last bottom widget's tap
  /// area is taller than its text. Defaults to [authFooterBottomTrim] when
  /// the last widget is an [AuthFooterLink].
  final double? bottomTrim;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final topPad = math.max(top, media.viewPadding.top + 12);
    final hasFooter = bottom.isNotEmpty && bottom.last is AuthFooterLink;
    final trim = bottomTrim ?? (hasFooter ? authFooterBottomTrim : 0);
    final bottomPad = keyboardOpen
        ? 4.0
        : math.max(36.0, media.viewPadding.bottom + 16) - trim;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: PasyarColors.card,
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, topPad, 20, 20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: gap,
                  children: [
                    if (onBack != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: RoundIconButton.ground(
                          icon: LucideIcons.chevronLeft,
                          semanticLabel: 'Back',
                          onPressed: onBack,
                        ),
                      ),
                    ?leading,
                    _TitleBlock(
                      title: title,
                      subtitle: subtitle,
                      size: titleSize,
                      height: titleHeight,
                      subtitleGap: subtitleGap,
                      subtitleHeight: subtitleHeight,
                    ),
                    ...children,
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.subtitle,
    required this.size,
    required this.height,
    required this.subtitleGap,
    required this.subtitleHeight,
  });

  final String title;
  final String? subtitle;
  final double size;
  final double height;
  final double subtitleGap;
  final double subtitleHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: subtitleGap,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: PasyarTextStyles.screenTitle(size).copyWith(height: height),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: PasyarTextStyles.body.copyWith(
              fontSize: 16,
              height: subtitleHeight,
              color: PasyarColors.muted,
            ),
          ),
      ],
    );
  }
}

/// "New here? Create an account" footer. The link has a 44 px tap area; the
/// row is laid out so the text sits where the mockup puts it (14 px below
/// the button, 36 px above the bottom edge).
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.text,
    required this.link,
    required this.onTap,
  });

  final String text;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = PasyarTextStyles.body.copyWith(
      height: 1.2,
      color: PasyarColors.muted,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      // Wraps onto two lines with very large system text instead of
      // overflowing.
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (text.isNotEmpty) Text('$text ', style: base),
          Semantics(
            button: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: Text(
                    link,
                    style: base.copyWith(
                      fontWeight: FontWeight.w600,
                      color: PasyarColors.accentDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom padding under [AuthFooterLink] is 13 px smaller than the
/// mockup's 36 px because the link's tap area is taller than its text.
const authFooterBottomTrim = 13.0;

/// Error message above the main button.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message!,
          textAlign: TextAlign.center,
          style: PasyarTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: PasyarColors.accentDark,
          ),
        ),
      ),
    );
  }
}

/// Text link in the accentDark style ("Forgot password?") with a 44 px
/// tap height.
class AuthTextLink extends StatelessWidget {
  const AuthTextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 44,
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: PasyarTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: PasyarColors.accentDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large `accentTint` circle with an icon, used at the top of message screens.
class AuthIconBadge extends StatelessWidget {
  const AuthIconBadge({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        width: 88,
        height: 88,
        decoration: const BoxDecoration(
          color: PasyarColors.accentTint,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 36, color: PasyarColors.accentDark),
      ),
    );
  }
}
