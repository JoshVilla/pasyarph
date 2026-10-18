import 'package:flutter/material.dart';

import '../../../core/theme/pasyar_theme.dart';

/// Grey placeholder shaped like a ride post, shown while the first page
/// loads.
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: PasyarColors.ground,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    return Semantics(
      label: 'Loading post',
      child: ColoredBox(
        color: PasyarColors.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                spacing: 10,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: PasyarColors.ground,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 8,
                    children: [bar(200, 12), bar(130, 10)],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: bar(280, 12),
            ),
            Container(height: 263, color: PasyarColors.ground),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: PasyarColors.ground,
                  borderRadius: BorderRadius.circular(PasyarRadius.choiceCard),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
