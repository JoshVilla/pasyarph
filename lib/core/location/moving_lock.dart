import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'location_provider.dart';

/// What locked fields say while the phone is moving.
const movingLockMessage = 'Stop riding to type.';

/// True while the phone moves faster than 10 km/h, so typing and posting
/// are off (CLAUDE.md rule). Rebuilds the caller when it changes. False
/// where there's no location (e.g. a widget tested on its own).
bool watchMoving(BuildContext context) {
  try {
    return context.watch<LocationProvider>().isMoving;
  } on ProviderNotFoundException {
    return false;
  }
}
