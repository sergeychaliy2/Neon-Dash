import '../config/game_config.dart';

class DifficultyCurve {
  const DifficultyCurve(this._config);

  final DifficultyConfig _config;

  double scrollSpeedAt(double elapsed) => _ramp(
        _config.startScrollSpeed,
        _config.maxScrollSpeed,
        _config.speedRampSeconds,
        elapsed,
      );

  double spawnIntervalAt(double elapsed) => _ramp(
        _config.startSpawnInterval,
        _config.minSpawnInterval,
        _config.spawnRampSeconds,
        elapsed,
      );

  double gapFractionAt(double elapsed) => _ramp(
        _config.startGapFraction,
        _config.minGapFraction,
        _config.gapRampSeconds,
        elapsed,
      );

  static double _ramp(
    double from,
    double to,
    double rampSeconds,
    double elapsed,
  ) {
    if (rampSeconds <= 0.0 || elapsed >= rampSeconds) return to;
    if (elapsed <= 0.0) return from;
    return from + (to - from) * (elapsed / rampSeconds);
  }
}
