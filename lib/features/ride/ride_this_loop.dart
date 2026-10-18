import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/location/location_provider.dart';
import '../../core/router.dart';
import 'providers/loop_preview_provider.dart';

/// Ride this loop (feed posts, your loops): the loop from where the rider
/// is, then the normal preview (START RIDE as for a generated loop).
Future<void> rideThisLoop(
  BuildContext context, {
  required String loopId,
  required String name,
}) async {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  final here = context.read<LocationProvider>().position;
  if (here == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Turn on location to ride this loop.')),
    );
    return;
  }
  final preview = context.read<LoopPreviewProvider>();
  messenger.showSnackBar(
    SnackBar(
      content: Text('Finding your way to $name…'),
      duration: const Duration(minutes: 1),
    ),
  );
  final ready = await preview.rideLoop(loopId: loopId, name: name, start: here);
  if (!context.mounted) return;
  messenger.hideCurrentSnackBar();
  if (ready) {
    context.push(Routes.loopPreview);
  } else if (preview.error != null) {
    messenger.showSnackBar(SnackBar(content: Text(preview.error!.message)));
  }
}
