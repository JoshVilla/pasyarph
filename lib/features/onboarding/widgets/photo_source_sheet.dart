import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/pasyar_theme.dart';
import '../../../core/widgets/widgets.dart';

enum PhotoChoice { camera, gallery, remove }

/// Bottom sheet: take a photo, pick from gallery, or remove the current one.
Future<PhotoChoice?> showPhotoSourceSheet(
  BuildContext context, {
  required bool canRemove,
}) {
  return showModalBottomSheet<PhotoChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => BottomSheetPanel(
      gap: 4,
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        const SizedBox(height: 8),
        _Option(
          icon: LucideIcons.camera,
          label: 'Take a photo',
          onTap: () => Navigator.pop(context, PhotoChoice.camera),
        ),
        _Option(
          icon: LucideIcons.image,
          label: 'Choose from gallery',
          onTap: () => Navigator.pop(context, PhotoChoice.gallery),
        ),
        if (canRemove)
          _Option(
            icon: LucideIcons.trash2,
            label: 'Remove photo',
            onTap: () => Navigator.pop(context, PhotoChoice.remove),
          ),
      ],
    ),
  );
}

ImageSource? imageSourceFor(PhotoChoice choice) => switch (choice) {
  PhotoChoice.camera => ImageSource.camera,
  PhotoChoice.gallery => ImageSource.gallery,
  PhotoChoice.remove => null,
};

class _Option extends StatelessWidget {
  const _Option({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PasyarRadius.input),
        child: SizedBox(
          height: 56,
          child: Row(
            spacing: 14,
            children: [
              Icon(icon, size: 22, color: PasyarColors.ink),
              Text(label, style: PasyarTextStyles.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
