import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router.dart';
import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/widgets/auth_scaffold.dart';
import '../link_messages.dart';

/// A share link that is loading, failed, or can't be opened: the white
/// auth layout (like JOIN CLUB) with one button at the bottom.
class LinkScaffold extends StatelessWidget {
  const LinkScaffold.loading({super.key, required this.title, this.text})
    : message = null,
      error = null,
      onRetry = null,
      retryLabel = null;

  const LinkScaffold.blocked(LinkMessage this.message, {super.key})
    : title = '',
      text = null,
      error = null,
      onRetry = null,
      retryLabel = null;

  const LinkScaffold.error({
    super.key,
    required this.title,
    required String this.error,
    required VoidCallback this.onRetry,
    this.retryLabel = 'TRY AGAIN',
  }) : message = null,
       text = null;

  final String title;
  final String? text;
  final LinkMessage? message;
  final String? error;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    void home() => context.go(Routes.home);
    return AuthScaffold(
      title: message?.title ?? title,
      subtitle: message?.text ?? text,
      onBack: () => context.canPop() ? context.pop() : home(),
      bottom: [
        AuthErrorText(error),
        if (onRetry != null)
          PrimaryButton(label: retryLabel!, onPressed: onRetry)
        else if (message != null)
          SecondaryButton(label: 'GO TO HOME', onPressed: home),
      ],
      children: [
        MotionChange(
          value: (message, error),
          duration: PasyarMotion.feedback,
          child: message == null && error == null
              ? Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: PasyarColors.of(context).accent,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
