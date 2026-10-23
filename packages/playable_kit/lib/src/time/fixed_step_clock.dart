class FixedStepClock {
  FixedStepClock({required this.stepSeconds, required this.maxStepsPerFrame})
      : assert(stepSeconds > 0.0, 'a step of zero would never advance'),
        assert(maxStepsPerFrame > 0, 'a frame must be allowed one step');

  final double stepSeconds;

  final int maxStepsPerFrame;

  double _accumulator = 0.0;

  double get pending => _accumulator;

  double get interpolation => _accumulator / stepSeconds;

  void reset() => _accumulator = 0.0;

  int consume(double realSeconds) {
    if (realSeconds <= 0.0) return 0;

    final budget = stepSeconds * maxStepsPerFrame;
    _accumulator += realSeconds > budget ? budget : realSeconds;

    var steps = 0;
    while (_accumulator >= stepSeconds && steps < maxStepsPerFrame) {
      _accumulator -= stepSeconds;
      steps++;
    }
    return steps;
  }
}
