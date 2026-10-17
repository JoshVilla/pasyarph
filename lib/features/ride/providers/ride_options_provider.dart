import 'package:flutter/foundation.dart';

/// How long the rider wants to ride. [value] is what generate-loop expects.
enum LoopDuration {
  quick('quick', 'QUICK', 'about 1 hr'),
  halfDay('half_day', 'HALF-DAY', 'about 4 hr'),
  fullDay('full_day', 'FULL DAY', '6 hr +');

  const LoopDuration(this.value, this.title, this.subtitle);

  final String value;
  final String title;
  final String subtitle;
}

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
