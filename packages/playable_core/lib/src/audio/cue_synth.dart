import 'dart:math' as math;

import 'package:playable_kit/playable_kit.dart';

import 'sound_cue.dart';

class CueSynth {
  CueSynth({
    this.sampleRate = defaultSampleRate,
    int noiseSeed = defaultNoiseSeed,
  })  : _noise = DeterministicRandom(noiseSeed),
        _filter = OnePoleLowPass(sampleRate);

  static const int defaultSampleRate = 44100;

  static const int defaultNoiseSeed = 0x51A7;

  static const double _edgeFadeSeconds = 0.004;

  final int sampleRate;
  final DeterministicRandom _noise;
  final OnePoleLowPass _filter;

  PcmBuffer render(SoundCue cue) => switch (cue) {
        SoundCue.runStart => renderRunStart(),
        SoundCue.nearMiss => renderNearMiss(),
        SoundCue.orbPickup => renderOrbPickup(),
        SoundCue.speedUp => renderSpeedUp(),
        SoundCue.bonusPickup => renderBonusPickup(),
        SoundCue.bonusSpend => renderBonusSpend(),
        SoundCue.shieldHit => renderShieldHit(),
        SoundCue.portalEnter => renderPortalEnter(),
        SoundCue.portalLeave => renderPortalLeave(),
        SoundCue.checkpoint => renderCheckpoint(),
        SoundCue.stageClear => renderStageClear(),
        SoundCue.crash => renderCrash(),
      };

  PcmBuffer renderRunStart() {
    const seconds = 0.5;
    const fromHz = 180.0;
    const toHz = 720.0;
    const fifthRatio = 1.5;
    const fifthGain = 0.45;
    const envelope = AttackDecay(attackSeconds: 0.02, decayRate: 3.0);
    const peak = 0.8;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;

    var phase = 0.0;
    var fifthPhase = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final time = i / sampleRate;
      final frequency = glide(fromHz, toHz, time / seconds);
      samples[i] = (sineAt(phase) + sineAt(fifthPhase) * fifthGain) *
          envelope.amplitudeAt(time);
      phase = advancePhase(phase, frequency, sampleRate);
      fifthPhase = advancePhase(fifthPhase, frequency * fifthRatio, sampleRate);
    }

    buffer.normalizeTo(peak);
    buffer.applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }

  PcmBuffer renderNearMiss() {
    const seconds = 0.26;
    const cutoffFromHz = 7000.0;
    const cutoffToHz = 520.0;
    const envelope = AttackDecay(attackSeconds: 0.006, decayRate: 11.0);
    const peak = 0.5;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;
    _filter.reset();

    for (var i = 0; i < samples.length; i++) {
      final time = i / sampleRate;
      final cutoff = glide(cutoffFromHz, cutoffToHz, time / seconds);
      final noise = _noise.nextRange(-1.0, 1.0);
      samples[i] = _filter.process(noise, cutoff) * envelope.amplitudeAt(time);
    }

    buffer.normalizeTo(peak);
    buffer.applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }

  PcmBuffer renderOrbPickup() {
    const seconds = 0.24;
    const firstNoteSeconds = 0.075;
    const firstHz = 880.0;
    const secondHz = 1320.0;
    const octaveRatio = 2.0;
    const shimmerGain = 0.3;
    const envelope = AttackDecay(attackSeconds: 0.004, decayRate: 13.0);
    const peak = 0.7;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;

    var phase = 0.0;
    var shimmerPhase = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final time = i / sampleRate;
      final onSecondNote = time >= firstNoteSeconds;
      final frequency = onSecondNote ? secondHz : firstHz;
      final noteTime = onSecondNote ? time - firstNoteSeconds : time;

      samples[i] = (triangleAt(phase) + sineAt(shimmerPhase) * shimmerGain) *
          envelope.amplitudeAt(noteTime);
      phase = advancePhase(phase, frequency, sampleRate);
      shimmerPhase =
          advancePhase(shimmerPhase, frequency * octaveRatio, sampleRate);
    }

    buffer.normalizeTo(peak);
    buffer.applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }

  PcmBuffer renderSpeedUp() {
    const seconds = 0.14;
    const fromHz = 520.0;
    const toHz = 800.0;
    const cutoffHz = 2600.0;
    const envelope = AttackDecay(attackSeconds: 0.004, decayRate: 20.0);
    const peak = 0.4;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;
    _filter.reset();

    var phase = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final time = i / sampleRate;
      final frequency = glide(fromHz, toHz, time / seconds);
      samples[i] = _filter.process(squareAt(phase), cutoffHz) *
          envelope.amplitudeAt(time);
      phase = advancePhase(phase, frequency, sampleRate);
    }

    buffer.normalizeTo(peak);
    buffer.applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }

  PcmBuffer renderBonusPickup() {
    const seconds = 0.26;
    const fromHz = 660.0;
    const toHz = 990.0;
    const fifthGain = 0.4;
    const envelope = AttackDecay(attackSeconds: 0.008, decayRate: 9.0);
    const peak = 0.55;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;

    var phase = 0.0;
    var fifthPhase = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final time = i / sampleRate;
      final frequency = glide(fromHz, toHz, time / seconds);

      samples[i] = (sineAt(phase) + sineAt(fifthPhase) * fifthGain) *
          envelope.amplitudeAt(time);
      phase = advancePhase(phase, frequency, sampleRate);
      fifthPhase = advancePhase(fifthPhase, frequency * 1.5, sampleRate);
    }

    buffer.normalizeTo(peak);
    buffer.applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }

  PcmBuffer renderBonusSpend() {
    const seconds = 0.45;
    const fromHz = 880.0;
    const toHz = 220.0;
    const cutoffFromHz = 900.0;
    const cutoffToHz = 5200.0;
    const noiseGain = 0.5;
    const envelope = AttackDecay(attackSeconds: 0.006, decayRate: 6.5);
    const peak = 0.8;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;
    _filter.reset();

    var phase = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final time = i / sampleRate;
      final progress = time / seconds;

      final body = sawtoothAt(phase);
      final swell = _filter.process(
            _noise.nextRange(-1.0, 1.0),
            glide(cutoffFromHz, cutoffToHz, progress),
          ) *
          noiseGain *
          progress;

      samples[i] = softClip(body + swell) * envelope.amplitudeAt(time);
      phase = advancePhase(
        phase,
        glide(fromHz, toHz, progress),
        sampleRate,
      );
    }

    buffer.normalizeTo(peak);
    buffer.applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }

  PcmBuffer renderPortalEnter() => _renderPortalSweep(rising: true);

  PcmBuffer renderPortalLeave() => _renderPortalSweep(rising: false);

  PcmBuffer _renderPortalSweep({required bool rising}) {
    const seconds = 0.45;
    const lowHz = 150.0;
    const highHz = 900.0;
    const detune = 1.012;
    const cutoffLowHz = 400.0;
    const cutoffHighHz = 5200.0;
    const peak = 0.7;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;
    _filter.reset();

    var phase = 0.0;
    var detunedPhase = 0.0;

    for (var i = 0; i < samples.length; i++) {
      final along = i / samples.length;
      final sweep = rising ? along : 1.0 - along;

      final frequency = lowHz * math.pow(highHz / lowHz, sweep).toDouble();
      final cutoff =
          cutoffLowHz * math.pow(cutoffHighHz / cutoffLowHz, sweep).toDouble();

      final shape = math.sin(along * math.pi);
      final value = (sawtoothAt(phase) + sawtoothAt(detunedPhase)) * 0.5;

      samples[i] = _filter.process(value, cutoff) * shape;

      phase = advancePhase(phase, frequency, sampleRate);
      detunedPhase = advancePhase(detunedPhase, frequency * detune, sampleRate);
    }

    buffer
      ..normalizeTo(peak)
      ..applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }

  PcmBuffer renderShieldHit() {
    const seconds = 0.5;
    const bodyHz = 320.0;
    const overtoneRatio = 2.76;
    const overtoneGain = 0.45;
    const cutoffHz = 1800.0;
    const noiseGain = 0.3;
    const envelope = AttackDecay(attackSeconds: 0.002, decayRate: 7.0);
    const peak = 0.75;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;
    _filter.reset();

    var phase = 0.0;
    var overtonePhase = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final time = i / sampleRate;

      final body =
          sineAt(phase) + triangleAt(overtonePhase) * overtoneGain;
      final grit = _filter.process(_noise.nextRange(-1.0, 1.0), cutoffHz) *
          noiseGain *
          envelope.amplitudeAt(time * 3.0);

      samples[i] = softClip(body + grit) * envelope.amplitudeAt(time);
      phase = advancePhase(phase, bodyHz, sampleRate);
      overtonePhase =
          advancePhase(overtonePhase, bodyHz * overtoneRatio, sampleRate);
    }

    buffer.normalizeTo(peak);
    buffer.applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }

  PcmBuffer renderCheckpoint() {
    const seconds = 0.3;
    const firstNoteSeconds = 0.06;
    const firstHz = 1320.0;
    const secondHz = 1976.0;
    const envelope = AttackDecay(attackSeconds: 0.003, decayRate: 11.0);
    const peak = 0.75;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;

    var phase = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final time = i / sampleRate;
      final onSecond = time >= firstNoteSeconds;
      final frequency = onSecond ? secondHz : firstHz;
      final noteTime = onSecond ? time - firstNoteSeconds : time;

      samples[i] = triangleAt(phase) * envelope.amplitudeAt(noteTime);
      phase = advancePhase(phase, frequency, sampleRate);
    }

    buffer.normalizeTo(peak);
    buffer.applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }

  PcmBuffer renderStageClear() {
    const seconds = 1.0;
    const noteSeconds = 0.13;
    const steps = <double>[523.25, 659.25, 783.99, 1046.5];
    const fifthGain = 0.35;
    const envelope = AttackDecay(attackSeconds: 0.006, decayRate: 4.2);
    const peak = 0.9;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;

    var phase = 0.0;
    var fifthPhase = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final time = i / sampleRate;
      var step = (time / noteSeconds).floor();
      if (step >= steps.length) step = steps.length - 1;

      final frequency = steps[step];
      final noteTime = time - step * noteSeconds;

      samples[i] = (triangleAt(phase) + sineAt(fifthPhase) * fifthGain) *
          envelope.amplitudeAt(noteTime);

      phase = advancePhase(phase, frequency, sampleRate);
      fifthPhase = advancePhase(fifthPhase, frequency * 1.5, sampleRate);
    }

    buffer.normalizeTo(peak);
    buffer.applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }

  PcmBuffer renderCrash() {
    const seconds = 0.8;
    const noiseCutoffFromHz = 9000.0;
    const noiseCutoffToHz = 300.0;
    const bodyFromHz = 170.0;
    const bodyToHz = 38.0;
    const bodyGain = 0.85;
    const drive = 1.8;
    const envelope = AttackDecay(attackSeconds: 0.002, decayRate: 4.2);
    const peak = 0.95;

    final buffer = PcmBuffer.silent(sampleRate: sampleRate, seconds: seconds);
    final samples = buffer.samples;
    _filter.reset();

    var phase = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final time = i / sampleRate;
      final progress = time / seconds;

      final noise = _filter.process(
        _noise.nextRange(-1.0, 1.0),
        glide(noiseCutoffFromHz, noiseCutoffToHz, progress),
      );
      final body = sawtoothAt(phase) * bodyGain;

      samples[i] = softClip((noise + body) * drive) * envelope.amplitudeAt(time);
      phase = advancePhase(
        phase,
        glide(bodyFromHz, bodyToHz, progress),
        sampleRate,
      );
    }

    buffer.normalizeTo(peak);
    buffer.applyEdgeFade(_edgeFadeSeconds);
    return buffer;
  }
}
