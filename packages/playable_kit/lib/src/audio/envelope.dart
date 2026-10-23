import 'dart:math' as math;

class AttackDecay {
  const AttackDecay({required this.attackSeconds, required this.decayRate});

  final double attackSeconds;

  final double decayRate;

  double amplitudeAt(double seconds) {
    if (seconds <= 0.0) return 0.0;
    if (seconds < attackSeconds) return seconds / attackSeconds;
    return math.exp(-(seconds - attackSeconds) * decayRate);
  }
}

double lerp(double from, double to, double progress) {
  if (progress <= 0.0) return from;
  if (progress >= 1.0) return to;
  return from + (to - from) * progress;
}

double glide(double from, double to, double progress) {
  if (progress <= 0.0) return from;
  if (progress >= 1.0) return to;
  return from * math.pow(to / from, progress).toDouble();
}
