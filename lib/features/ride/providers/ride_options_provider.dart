import 'package:flutter/foundation.dart';

import '../../../data/models/generated_loop.dart';

/// Choices on the "WHERE TO TODAY?" sheet. Defaults match the mockup.
class RideOptionsProvider extends ChangeNotifier {
  LoopDuration _duration = LoopDuration.halfDay;
  bool _avoidHighways = true;
  bool _avoidUnpaved = false;
  int _days = 3;

  LoopDuration get duration => _duration;
  bool get avoidHighways => _avoidHighways;
  bool get avoidUnpaved => _avoidUnpaved;

  /// How many days, for [LoopDuration.multiDay] (2-7).
  int get days => _days;

  set days(int value) {
    if (value == _days) return;
    _days = value;
    notifyListeners();
  }

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
