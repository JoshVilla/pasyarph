import 'package:flutter/material.dart';

import '../theme/pasyar_theme.dart';
import 'panels.dart';

/// One row of [showActionSheet].
class SheetAction<T> {
  const SheetAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;

  /// Shown in `accentDark` (delete, remove).
  final bool destructive;
  final bool enabled;
}

/// A bottom sheet of actions (a post's or a loop's ⋯ menu): 56 px rows,
/// big enough for gloves. Returns the picked action's value.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  String? title,
  required List<SheetAction<T>> actions,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => BottomSheetPanel(
      gap: 4,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PasyarTextStyles.screenTitle(24),
            ),
          ),
        for (final a in actions) _ActionRow(action: a),
      ],
    ),
  );
}

class _ActionRow<T> extends StatelessWidget {
  const _ActionRow({required this.action});

  final SheetAction<T> action;

  @override
  Widget build(BuildContext context) {
    final color = !action.enabled
        ? PasyarColors.muted
        : action.destructive
        ? PasyarColors.accentDark
        : PasyarColors.ink;
    return Semantics(
      button: true,
      enabled: action.enabled,
      label: action.label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: action.enabled
              ? () => Navigator.of(context).pop(action.value)
              : null,
          child: SizedBox(
            height: 56,
            child: Row(
              spacing: 14,
              children: [
                const SizedBox(width: 4),
                Icon(action.icon, size: 22, color: color),
                Expanded(
                  child: Text(
                    action.label,
                    style: PasyarTextStyles.bodyLarge.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
