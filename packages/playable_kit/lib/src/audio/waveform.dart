library;

import 'dart:math' as math;

const double _tau = 6.283185307179586;

double sineAt(double phase) => math.sin(phase * _tau);

double triangleAt(double phase) {
  final folded = phase < 0.5 ? phase * 2.0 : (1.0 - phase) * 2.0;
  return folded * 2.0 - 1.0;
}

double sawtoothAt(double phase) => phase * 2.0 - 1.0;

double squareAt(double phase) => phase < 0.5 ? 1.0 : -1.0;

double advancePhase(double phase, double frequency, int sampleRate) {
  var next = phase + frequency / sampleRate;
  if (next >= 1.0) next -= 1.0;
  return next;
}

double softClip(double x) {
  final squared = x * x;
  final shaped = x * (27.0 + squared) / (27.0 + 9.0 * squared);
  if (shaped > 1.0) return 1.0;
  if (shaped < -1.0) return -1.0;
  return shaped;
}

class OnePoleHighPass {
  OnePoleHighPass(int sampleRate) : _lowPass = OnePoleLowPass(sampleRate);

  final OnePoleLowPass _lowPass;

  void reset() => _lowPass.reset();

  double process(double sample, double cutoffHz) =>
      sample - _lowPass.process(sample, cutoffHz);
}

class OnePoleLowPass {
  OnePoleLowPass(this.sampleRate);

  final int sampleRate;
  double _state = 0.0;

  void reset() => _state = 0.0;

  double process(double sample, double cutoffHz) {
    final alpha = 1.0 - math.exp(-_tau * cutoffHz / sampleRate);
    _state += (sample - _state) * alpha;
    return _state;
  }
}
