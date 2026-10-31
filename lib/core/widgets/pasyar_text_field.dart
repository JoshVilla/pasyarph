import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../location/moving_lock.dart';
import '../theme/pasyar_theme.dart';

/// Label above a 52 px field, with optional helper or error text below.
/// Set [password] for a hidden field with a 44 × 44 show/hide toggle.
/// Disabled while the phone is moving (see [watchMoving]).
class PasyarTextField extends StatefulWidget {
  const PasyarTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.error,
    this.password = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.height = 52,
    this.textStyle,
    this.maxLength,
    this.maxLines = 1,
    this.prefixText,
  });

  /// 52 by default; the Create sheet's loop name field is 48.
  final double height;

  /// Text and hint style; defaults to 16 px body text.
  final TextStyle? textStyle;

  /// Limits input without showing a counter.
  final int? maxLength;

  /// More than 1 for a multi-line field (a bio); it grows to fit.
  final int maxLines;

  /// Shown before the text, e.g. "@" for a username.
  final String? prefixText;

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? helper;

  /// Shown instead of [helper] and turns the border `accent`.
  final String? error;
  final bool password;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasyarTextField> createState() => _PasyarTextFieldState();
}

class _PasyarTextFieldState extends State<PasyarTextField> {
  bool _obscured = true;

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(PasyarRadius.input),
    borderSide: BorderSide(color: color, width: width),
  );

  @override
  Widget build(BuildContext context) {
    final textStyle =
        widget.textStyle ??
        PasyarTextStyles.of(context).body.copyWith(fontSize: 16, height: 1.2);
    // Every field locks while riding, wherever it is.
    final moving = watchMoving(context);
    final enabled = widget.enabled && !moving;
    final hasError = widget.error != null;
    final message =
        widget.error ?? (moving ? movingLockMessage : null) ?? widget.helper;
    final idle = hasError
        ? _border(PasyarColors.of(context).accent, 2)
        : _border(PasyarColors.of(context).line, 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(widget.label, style: PasyarTextStyles.of(context).fieldLabel),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: enabled,
          obscureText: widget.password && _obscured,
          enableSuggestions: !widget.password,
          autocorrect: !widget.password,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          textAlignVertical: TextAlignVertical.center,
          maxLength: widget.maxLength,
          minLines: widget.maxLines > 1 ? 3 : 1,
          maxLines: widget.maxLines,
          style: textStyle.copyWith(
            color: enabled
                ? PasyarColors.of(context).ink
                : PasyarColors.of(context).muted,
          ),
          decoration: InputDecoration(
            constraints: widget.maxLines == 1
                ? BoxConstraints.tightFor(height: widget.height)
                : null,
            contentPadding: widget.maxLines == 1
                ? const EdgeInsets.symmetric(horizontal: 14)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            // Always shown (prefixText only shows once focused or filled).
            prefixIcon: widget.prefixText == null
                ? null
                : Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 14,
                      end: 2,
                    ),
                    child: Text(
                      widget.prefixText!,
                      style: textStyle.copyWith(
                        color: PasyarColors.of(context).muted,
                      ),
                    ),
                  ),
            prefixIconConstraints: const BoxConstraints(),
            counterText: '',
            hintText: widget.hint,
            hintStyle: textStyle.copyWith(
              color: PasyarColors.of(context).muted,
            ),
            filled: true,
            fillColor: enabled
                ? PasyarColors.of(context).card
                : PasyarColors.of(context).ground,
            border: idle,
            enabledBorder: idle,
            disabledBorder: _border(PasyarColors.of(context).line, 1.5),
            focusedBorder: hasError
                ? idle
                : _border(PasyarColors.of(context).ink, 1.5),
            suffixIcon: widget.password
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: IconButton(
                      onPressed: () => setState(() => _obscured = !_obscured),
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 20,
                        color: PasyarColors.of(context).muted,
                      ),
                      constraints: const BoxConstraints.tightFor(
                        width: 44,
                        height: 44,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 44,
            ),
          ),
        ),
        if (message != null)
          Text(
            message,
            style: PasyarTextStyles.of(context).label.copyWith(
              color: hasError
                  ? PasyarColors.of(context).accentDark
                  : PasyarColors.of(context).muted,
              fontWeight: hasError ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
      ],
    );
  }
}
