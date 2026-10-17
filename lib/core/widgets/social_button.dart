import 'package:flutter/material.dart';

import '../theme/pasyar_theme.dart';

enum SocialProvider { apple, google }

/// 52 px sign-in button. Apple is `ink` with white text and always goes
/// first; Google is white with a `line` border. Width comes from the parent:
/// full width on Log in ("Continue with Apple"), half width on Register
/// ("Apple") with [compact] set.
///
/// The provider marks are the letter placeholders from the mockups. Swap
/// [_ProviderMark] for the official Apple and Google logos when sign-in is
/// built, following each provider's button guidelines.
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.provider,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.loading = false,
  });

  final SocialProvider provider;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final apple = provider == SocialProvider.apple;
    final foreground = apple ? PasyarColors.card : PasyarColors.ink;
    final enabled = onPressed != null && !loading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? 0.4 : 1,
        child: SizedBox(
          height: 52,
          child: Material(
            color: apple ? PasyarColors.ink : PasyarColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PasyarRadius.social),
              side: apple
                  ? BorderSide.none
                  : const BorderSide(color: PasyarColors.line, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              child: Center(
                child: loading
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: foreground,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: compact ? 10 : 12,
                          children: [
                            _ProviderMark(provider),
                            Text(
                              label,
                              maxLines: 1,
                              style: PasyarTextStyles.body.copyWith(
                                fontSize: 16,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                color: foreground,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderMark extends StatelessWidget {
  const _ProviderMark(this.provider);

  final SocialProvider provider;

  @override
  Widget build(BuildContext context) {
    final apple = provider == SocialProvider.apple;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: apple ? PasyarColors.card : PasyarColors.ground,
      ),
      child: Text(
        apple ? 'A' : 'G',
        style: PasyarTextStyles.body.copyWith(
          height: 1,
          fontSize: apple ? 13 : 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
