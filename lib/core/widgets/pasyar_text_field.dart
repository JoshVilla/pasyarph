import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/pasyar_theme.dart';

/// Label above a 52 px field, with optional helper or error text below.
/// Set [password] for a hidden field with a 44 × 44 show/hide toggle.
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
  });

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
    final hasError = widget.error != null;
    final message = widget.error ?? widget.helper;
    final idle = hasError
        ? _border(PasyarColors.accent, 2)
        : _border(PasyarColors.line, 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(widget.label, style: PasyarTextStyles.fieldLabel),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
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
          style: PasyarTextStyles.body.copyWith(
            fontSize: 16,
            height: 1.2,
            color: widget.enabled ? PasyarColors.ink : PasyarColors.muted,
          ),
          decoration: InputDecoration(
            constraints: const BoxConstraints.tightFor(height: 52),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            hintText: widget.hint,
            hintStyle: PasyarTextStyles.body.copyWith(
              fontSize: 16,
              height: 1.2,
              color: PasyarColors.muted,
            ),
            filled: true,
            fillColor: widget.enabled ? PasyarColors.card : PasyarColors.ground,
            border: idle,
            enabledBorder: idle,
            disabledBorder: _border(PasyarColors.line, 1.5),
            focusedBorder: hasError ? idle : _border(PasyarColors.ink, 1.5),
            suffixIcon: widget.password
                ? Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: IconButton(
                      onPressed: () => setState(() => _obscured = !_obscured),
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                        size: 20,
                        color: PasyarColors.muted,
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
            style: PasyarTextStyles.label.copyWith(
              color: hasError ? PasyarColors.accentDark : PasyarColors.muted,
              fontWeight: hasError ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
      ],
    );
  }
}
