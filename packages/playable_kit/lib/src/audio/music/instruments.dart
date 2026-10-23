library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../../random/deterministic_random.dart';
import '../envelope.dart';
import '../waveform.dart';

const double _tau = 6.283185307179586;

double frequencyOfSemitone(double semitonesFromA4) =>
    440.0 * math.pow(2.0, semitonesFromA4 / 12.0).toDouble();

void _mix(Float32List out, int index, double value) {
  out[index % out.length] += value;
}

void renderKick({
  required Float32List out,
  required int startSample,
  required int sampleRate,
  required double gain,
}) {
  const seconds = 0.34;
  const fromHz = 155.0;
  const toHz = 46.0;
  const pitchDropSeconds = 0.075;
  const envelope = AttackDecay(attackSeconds: 0.001, decayRate: 17.0);
  const drive = 1.35;

  final frames = (sampleRate * seconds).round();
  var phase = 0.0;

  for (var i = 0; i < frames; i++) {
    final time = i / sampleRate;
    final progress = time / pitchDropSeconds;
    final frequency = glide(fromHz, toHz, progress > 1.0 ? 1.0 : progress);

    final value = softClip(sineAt(phase) * drive) * envelope.amplitudeAt(time);
    _mix(out, startSample + i, value * gain);

    phase = advancePhase(phase, frequency, sampleRate);
  }
}

void renderClap({
  required Float32List out,
  required int startSample,
  required int sampleRate,
  required double gain,
  required DeterministicRandom noise,
}) {
  const seconds = 0.26;
  const burstOffsets = <double>[0.0, 0.011, 0.023];
  const bodyHz = 190.0;
  const cutoffHz = 5200.0;
  const envelope = AttackDecay(attackSeconds: 0.001, decayRate: 19.0);
  const bodyEnvelope = AttackDecay(attackSeconds: 0.001, decayRate: 32.0);
  const bodyGain = 0.35;

  final frames = (sampleRate * seconds).round();
  final filter = OnePoleLowPass(sampleRate);
  var phase = 0.0;

  for (var i = 0; i < frames; i++) {
    final time = i / sampleRate;

    var amplitude = 0.0;
    for (final offset in burstOffsets) {
      if (time >= offset) amplitude += envelope.amplitudeAt(time - offset);
    }

    final hiss = filter.process(noise.nextRange(-1.0, 1.0), cutoffHz);
    final body = triangleAt(phase) * bodyGain * bodyEnvelope.amplitudeAt(time);
    _mix(out, startSample + i, (hiss * amplitude + body) * gain);

    phase = advancePhase(phase, bodyHz, sampleRate);
  }
}

void renderHat({
  required Float32List out,
  required int startSample,
  required int sampleRate,
  required double gain,
  required bool open,
  required DeterministicRandom noise,
}) {
  final seconds = open ? 0.16 : 0.055;
  final envelope = AttackDecay(
    attackSeconds: 0.0005,
    decayRate: open ? 22.0 : 70.0,
  );
  const cutoffHz = 7200.0;

  final frames = (sampleRate * seconds).round();
  final filter = OnePoleHighPass(sampleRate);

  for (var i = 0; i < frames; i++) {
    final time = i / sampleRate;
    final hiss = filter.process(noise.nextRange(-1.0, 1.0), cutoffHz);
    _mix(out, startSample + i, hiss * envelope.amplitudeAt(time) * gain);
  }
}

void renderTom({
  required Float32List out,
  required int startSample,
  required int sampleRate,
  required double pitchHz,
  required double gain,
}) {
  const seconds = 0.22;
  const dropRatio = 0.55;
  const envelope = AttackDecay(attackSeconds: 0.002, decayRate: 16.0);

  final frames = (sampleRate * seconds).round();
  var phase = 0.0;

  for (var i = 0; i < frames; i++) {
    final time = i / sampleRate;
    final frequency = pitchHz * (dropRatio + (1.0 - dropRatio) *
        math.exp(-time * 18.0));
    _mix(out, startSample + i, sineAt(phase) * envelope.amplitudeAt(time) *
        gain);
    phase = advancePhase(phase, frequency, sampleRate);
  }
}

void renderRiser({
  required Float32List out,
  required int startSample,
  required int sampleRate,
  required double seconds,
  required double gain,
  required DeterministicRandom noise,
}) {
  const fromHz = 300.0;
  const toHz = 8000.0;

  final frames = (sampleRate * seconds).round();
  if (frames <= 0) return;
  final filter = OnePoleHighPass(sampleRate);

  for (var i = 0; i < frames; i++) {
    final along = i / frames;
    final cutoff = fromHz * math.pow(toHz / fromHz, along).toDouble();
    final level = along * along;
    final hiss = filter.process(noise.nextRange(-1.0, 1.0), cutoff);
    _mix(out, startSample + i, hiss * level * gain);
  }
}

void renderBass({
  required Float32List out,
  required int startSample,
  required int sampleRate,
  required double frequencyHz,
  required double seconds,
  required double gain,
}) {
  const cutoffFromHz = 2400.0;
  const cutoffToHz = 260.0;
  const sweepSeconds = 0.14;
  const envelope = AttackDecay(attackSeconds: 0.004, decayRate: 7.5);
  const subGain = 0.5;
  const drive = 1.5;

  final frames = (sampleRate * seconds).round();
  final filter = OnePoleLowPass(sampleRate);
  var phase = 0.0;
  var subPhase = 0.0;

  for (var i = 0; i < frames; i++) {
    final time = i / sampleRate;
    final sweep = time / sweepSeconds;
    final cutoff = glide(cutoffFromHz, cutoffToHz, sweep > 1.0 ? 1.0 : sweep);

    final shaped = filter.process(sawtoothAt(phase), cutoff);
    final sub = sineAt(subPhase) * subGain;
    final value = softClip((shaped + sub) * drive) * envelope.amplitudeAt(time);
    _mix(out, startSample + i, value * gain);

    phase = advancePhase(phase, frequencyHz, sampleRate);
    subPhase = advancePhase(subPhase, frequencyHz * 0.5, sampleRate);
  }
}

void renderPluck({
  required Float32List out,
  required int startSample,
  required int sampleRate,
  required double frequencyHz,
  required double seconds,
  required double gain,
}) {
  const detune = 1.004;
  const cutoffHz = 4200.0;
  const envelope = AttackDecay(attackSeconds: 0.002, decayRate: 15.0);
  const detuneGain = 0.6;

  final frames = (sampleRate * seconds).round();
  final filter = OnePoleLowPass(sampleRate);
  var phase = 0.0;
  var detunedPhase = 0.0;

  for (var i = 0; i < frames; i++) {
    final time = i / sampleRate;
    final voice =
        triangleAt(phase) + sawtoothAt(detunedPhase) * detuneGain;
    final value = filter.process(voice, cutoffHz) * envelope.amplitudeAt(time);
    _mix(out, startSample + i, value * gain);

    phase = advancePhase(phase, frequencyHz, sampleRate);
    detunedPhase = advancePhase(detunedPhase, frequencyHz * detune, sampleRate);
  }
}

void renderBell({
  required Float32List out,
  required int startSample,
  required int sampleRate,
  required double frequencyHz,
  required double seconds,
  required double gain,
}) {
  const partialGain = 0.35;
  const envelope = AttackDecay(attackSeconds: 0.004, decayRate: 3.4);

  final frames = (sampleRate * seconds).round();
  var phase = 0.0;
  var partialPhase = 0.0;

  for (var i = 0; i < frames; i++) {
    final time = i / sampleRate;
    final value =
        (sineAt(phase) + sineAt(partialPhase) * partialGain) *
            envelope.amplitudeAt(time);
    _mix(out, startSample + i, value * gain);

    phase = advancePhase(phase, frequencyHz, sampleRate);
    partialPhase = advancePhase(partialPhase, frequencyHz * 2.01, sampleRate);
  }
}

void renderLead({
  required Float32List out,
  required int startSample,
  required int sampleRate,
  required double frequencyHz,
  required double seconds,
  required double gain,
}) {
  const vibratoHz = 5.5;
  const vibratoDepth = 0.006;
  const fifthGain = 0.3;
  const envelope = AttackDecay(attackSeconds: 0.035, decayRate: 2.2);

  final frames = (sampleRate * seconds).round();
  var phase = 0.0;
  var fifthPhase = 0.0;

  for (var i = 0; i < frames; i++) {
    final time = i / sampleRate;
    final vibrato = 1.0 + vibratoDepth * math.sin(time * _tau * vibratoHz);
    final frequency = frequencyHz * vibrato;

    final value = (triangleAt(phase) + sineAt(fifthPhase) * fifthGain) *
        envelope.amplitudeAt(time);
    _mix(out, startSample + i, value * gain);

    phase = advancePhase(phase, frequency, sampleRate);
    fifthPhase = advancePhase(fifthPhase, frequency * 1.5, sampleRate);
  }
}
