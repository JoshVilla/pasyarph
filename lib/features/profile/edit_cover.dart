import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/widgets.dart';
import '../me/cover_image.dart';
import 'providers/cover_controller.dart';
import 'screens/cover_crop_screen.dart';

enum CoverAction { camera, gallery, remove, cancel }

/// Picks a photo; replaceable in tests. Null when the rider backs out.
typedef PickPhoto = Future<Uint8List?> Function(ImageSource source);

Future<Uint8List?> _pickWithImagePicker(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 3000,
    maxHeight: 3000,
    imageQuality: 95,
  );
  return file?.readAsBytes();
}

/// "Edit cover": Take photo, Choose from gallery, Remove cover (when there
/// is one), Cancel. A new photo is cropped to the banner, compressed and
/// uploaded; failures keep the old cover and say so.
Future<void> editCover(
  BuildContext context, {
  PickPhoto pick = _pickWithImagePicker,
}) async {
  final covers = context.read<CoverController>();
  final messenger = ScaffoldMessenger.of(context);
  void snack(String text) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  final action = await showActionSheet<CoverAction>(
    context,
    title: 'COVER PHOTO',
    actions: [
      const SheetAction(
        value: CoverAction.camera,
        label: 'Take photo',
        icon: LucideIcons.camera,
      ),
      const SheetAction(
        value: CoverAction.gallery,
        label: 'Choose from gallery',
        icon: LucideIcons.image,
      ),
      if (covers.coverUrl != null)
        const SheetAction(
          value: CoverAction.remove,
          label: 'Remove cover',
          icon: LucideIcons.trash2,
          destructive: true,
        ),
      const SheetAction(
        value: CoverAction.cancel,
        label: 'Cancel',
        icon: LucideIcons.x,
      ),
    ],
  );
  if (!context.mounted) return;
  switch (action) {
    case null || CoverAction.cancel:
      return;
    case CoverAction.remove:
      final error = await covers.remove();
      if (error != null) snack(error);
    case CoverAction.camera || CoverAction.gallery:
      final Uint8List? picked;
      try {
        picked = await pick(
          action == CoverAction.camera
              ? ImageSource.camera
              : ImageSource.gallery,
        );
      } on Exception {
        return snack("Couldn't open that photo. Try another one.");
      }
      if (picked == null || !context.mounted) return;
      final CoverSource source;
      try {
        source = await compute(prepareCoverSource, picked);
      } on FormatException {
        return snack("Couldn't open that photo. Try another one.");
      }
      if (!context.mounted) return;
      final rect = await CoverCropScreen.open(context, source);
      if (rect == null) return;
      final jpeg = await compute(cropCoverJpeg, (source.bytes, rect));
      final error = await covers.save(jpeg);
      if (error != null) snack(error);
  }
}
