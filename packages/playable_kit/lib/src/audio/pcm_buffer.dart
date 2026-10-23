import 'dart:typed_data';

class PcmBuffer {
  PcmBuffer({required this.sampleRate, required this.samples});

  PcmBuffer.silent({required this.sampleRate, required double seconds})
      : samples = Float32List((sampleRate * seconds).round());

  final int sampleRate;
  final Float32List samples;

  int get frameCount => samples.length;

  double get durationSeconds => samples.length / sampleRate;

  double peak() {
    var highest = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final magnitude = samples[i] < 0.0 ? -samples[i] : samples[i];
      if (magnitude > highest) highest = magnitude;
    }
    return highest;
  }

  void normalizeTo(double target) {
    final highest = peak();
    if (highest <= 0.0) return;
    final gain = target / highest;
    for (var i = 0; i < samples.length; i++) {
      samples[i] *= gain;
    }
  }

  void applyEdgeFade(double seconds) {
    final fadeFrames = (sampleRate * seconds).round();
    if (fadeFrames <= 0) return;

    final usable = fadeFrames * 2 > samples.length
        ? samples.length ~/ 2
        : fadeFrames;

    for (var i = 0; i < usable; i++) {
      final gain = i / usable;
      samples[i] *= gain;
      samples[samples.length - 1 - i] *= gain;
    }
  }
}
