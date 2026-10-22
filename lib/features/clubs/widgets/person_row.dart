import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';

/// 60 px row: 40 px picture, name, optional muted detail, and a chevron.
/// A club member or a club in a list.
class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.name,
    required this.onTap,
    this.image,
    this.detail,
  });

  final String name;
  final ImageProvider? image;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PasyarRadius.input),
        child: SizedBox(
          height: 60,
          child: Row(
            spacing: 12,
            children: [
              Avatar(name: name, image: image, size: 40),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PasyarTextStyles.bodyStrong.copyWith(height: 1.2),
                    ),
                    if (detail case final d?)
                      Text(
                        d,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PasyarTextStyles.label.copyWith(height: 1.2),
                      ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 22,
                color: PasyarColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
