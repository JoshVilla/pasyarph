import 'package:flutter/foundation.dart';

import '../../../data/models/generated_loop.dart';

/// Choices on the "WHERE TO TODAY?" sheet. Defaults match the mockup.
class RideOptionsProvider extends ChangeNotifier {
  LoopDuration _duration = LoopDuration.halfDay;
  bool _avoidHighways = true;
  bool _avoidUnpaved = false;

  LoopDuration get duration => _duration;
  bool get avoidHighways => _avoidHighways;
  bool get avoidUnpaved => _avoidUnpaved;

  set duration(LoopDuration value) {
    if (value == _duration) return;
    _duration = value;
    notifyListeners();
  }

  set avoidHighways(bool value) {
    if (value == _avoidHighways) return;
    _avoidHighways = value;
    notifyListeners();
  }

  set avoidUnpaved(bool value) {
    if (value == _avoidUnpaved) return;
    _avoidUnpaved = value;
    notifyListeners();
  }
}
