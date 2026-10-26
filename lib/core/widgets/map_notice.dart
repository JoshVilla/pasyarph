import 'package:flutter/material.dart';

import '../theme/pasyar_theme.dart';

/// A floating notice shown on the map (ride status, errors, loading, etc.).
class MapNotice extends StatelessWidget {
  const MapNotice({
    super.key,
    required this.icon,
    required this.text,
  });

  const MapNotice.loading({
    super.key,
    required this.text,
  }) : icon = null;

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: PasyarColors.card,
        borderRadius: BorderRadius.circular(PasyarRadius.panel),
        boxShadow: PasyarShadows.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          if (icon == null)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 20, color: PasyarColors.accentDark),
          Flexible(
            child: Text(
              text,
              style: PasyarTextStyles.body.copyWith(height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
