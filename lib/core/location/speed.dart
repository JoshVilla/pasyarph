/// Typing and posting lock above this speed (see CLAUDE.md).
const movingThresholdKmh = 10.0;

/// GPS speed in m/s to km/h. Unknown or negative readings count as 0.
double speedKmh(double metersPerSecond) {
  if (metersPerSecond.isNaN || metersPerSecond <= 0) return 0;
  return metersPerSecond * 3.6;
}

bool isMovingAt(double kmh) => kmh > movingThresholdKmh;
