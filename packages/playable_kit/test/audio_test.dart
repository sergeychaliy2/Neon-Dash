import 'dart:typed_data';

import 'package:playable_kit/playable_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Waveforms', () {
    test('sine runs zero, peak, zero, trough across one cycle', () {
      expect(sineAt(0.0), closeTo(0.0, 1e-12));
      expect(sineAt(0.25), closeTo(1.0, 1e-12));
      expect(sineAt(0.5), closeTo(0.0, 1e-12));
      expect(sineAt(0.75), closeTo(-1.0, 1e-12));
    });

    test('triangle peaks at the half cycle', () {
      expect(triangleAt(0.0), closeTo(-1.0, 1e-12));
      expect(triangleAt(0.25), closeTo(0.0, 1e-12));
      expect(triangleAt(0.5), closeTo(1.0, 1e-12));
      expect(triangleAt(0.75), closeTo(0.0, 1e-12));
    });

    test('sawtooth rises linearly across the cycle', () {
      expect(sawtoothAt(0.0), closeTo(-1.0, 1e-12));
      expect(sawtoothAt(0.5), closeTo(0.0, 1e-12));
      expect(sawtoothAt(1.0), closeTo(1.0, 1e-12));
    });

    test('square switches at the half cycle', () {
      expect(squareAt(0.0), 1.0);
      expect(squareAt(0.49), 1.0);
      expect(squareAt(0.5), -1.0);
      expect(squareAt(0.99), -1.0);
    });

    test('advancePhase wraps into the unit interval', () {
      const sampleRate = 1000;
      var phase = 0.0;

      for (var i = 0; i < 10000; i++) {
        phase = advancePhase(phase, 440.0, sampleRate);
        expect(phase, greaterThanOrEqualTo(0.0));
        expect(phase, lessThan(1.0));
      }
    });

    test('softClip keeps every input inside the unit interval', () {
      for (final input in [-1000.0, -3.0, -1.0, 0.0, 0.5, 1.0, 3.0, 1000.0]) {
        final output = softClip(input);
        expect(output, greaterThanOrEqualTo(-1.0), reason: 'input $input');
        expect(output, lessThanOrEqualTo(1.0), reason: 'input $input');
      }
    });

    test('softClip is near-linear for small signals', () {
      expect(softClip(0.1), closeTo(0.1, 0.005));
      expect(softClip(-0.1), closeTo(-0.1, 0.005));
    });

    test('the low-pass attenuates high frequencies more than low ones', () {
      const sampleRate = 44100;
      const cutoffHz = 1000.0;

      final lowEnergy = _filteredEnergy(100.0, cutoffHz, sampleRate);
      final highEnergy = _filteredEnergy(10000.0, cutoffHz, sampleRate);

      expect(highEnergy, lessThan(lowEnergy * 0.5));
    });
  });

  group('Envelope', () {
    const envelope = AttackDecay(attackSeconds: 0.01, decayRate: 10.0);

    test('starts silent and reaches full amplitude at the attack', () {
      expect(envelope.amplitudeAt(0.0), 0.0);
      expect(envelope.amplitudeAt(0.005), closeTo(0.5, 1e-9));
      expect(envelope.amplitudeAt(0.01), closeTo(1.0, 1e-9));
    });

    test('decays monotonically after the attack', () {
      var previous = 1.0;
      for (var t = 0.01; t < 1.0; t += 0.01) {
        final amplitude = envelope.amplitudeAt(t);
        expect(amplitude, lessThanOrEqualTo(previous));
        previous = amplitude;
      }
      expect(previous, lessThan(0.01));
    });

    test('negative time is silent', () {
      expect(envelope.amplitudeAt(-1.0), 0.0);
    });

    test('glide is geometric, so a sweep sounds even', () {
      expect(glide(100.0, 1600.0, 0.5), closeTo(400.0, 1e-6));
      expect(glide(100.0, 1600.0, 0.0), 100.0);
      expect(glide(100.0, 1600.0, 1.0), 1600.0);
    });

    test('lerp clamps outside the unit interval', () {
      expect(lerp(2.0, 6.0, 0.5), 4.0);
      expect(lerp(2.0, 6.0, -1.0), 2.0);
      expect(lerp(2.0, 6.0, 2.0), 6.0);
    });
  });

  group('PcmBuffer', () {
    test('normalizeTo puts the loudest sample exactly at the target', () {
      final buffer = PcmBuffer(
        sampleRate: 1000,
        samples: Float32List.fromList([0.1, -0.4, 0.2]),
      )..normalizeTo(0.8);

      expect(buffer.peak(), closeTo(0.8, 1e-6));
      expect(buffer.samples[1], closeTo(-0.8, 1e-6));
    });

    test('normalizeTo leaves silence alone', () {
      final buffer = PcmBuffer(
        sampleRate: 1000,
        samples: Float32List(16),
      )..normalizeTo(0.8);

      expect(buffer.peak(), 0.0);
    });

    test('applyEdgeFade silences both ends', () {
      final samples = Float32List(100);
      samples.fillRange(0, 100, 1.0);
      final buffer = PcmBuffer(sampleRate: 1000, samples: samples)
        ..applyEdgeFade(0.01);

      expect(buffer.samples.first, 0.0);
      expect(buffer.samples.last, 0.0);
      expect(buffer.samples[50], 1.0, reason: 'the middle is untouched');
    });

    test('applyEdgeFade on a buffer shorter than the fade stays in bounds', () {
      final samples = Float32List(4);
      samples.fillRange(0, 4, 1.0);

      expect(
        () => PcmBuffer(sampleRate: 1000, samples: samples)
            .applyEdgeFade(10.0),
        returnsNormally,
      );
    });

    test('duration follows the sample rate', () {
      final buffer = PcmBuffer.silent(sampleRate: 1000, seconds: 0.25);

      expect(buffer.frameCount, 250);
      expect(buffer.durationSeconds, closeTo(0.25, 1e-9));
    });
  });

  group('WAV encoding', () {
    test('writes a canonical mono 16-bit header', () {
      final buffer = PcmBuffer.silent(sampleRate: 44100, seconds: 0.01);
      final bytes = encodeWavMono16(buffer);
      final view = ByteData.view(bytes.buffer);

      expect(_ascii(bytes, 0, 4), 'RIFF');
      expect(_ascii(bytes, 8, 4), 'WAVE');
      expect(_ascii(bytes, 12, 4), 'fmt ');
      expect(_ascii(bytes, 36, 4), 'data');

      expect(view.getUint32(16, Endian.little), 16, reason: 'fmt chunk size');
      expect(view.getUint16(20, Endian.little), 1, reason: 'PCM format tag');
      expect(view.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(view.getUint32(24, Endian.little), 44100);
      expect(view.getUint32(28, Endian.little), 44100 * 2, reason: 'byte rate');
      expect(view.getUint16(32, Endian.little), 2, reason: 'block align');
      expect(view.getUint16(34, Endian.little), 16, reason: 'bit depth');
    });

    test('declared sizes match the actual byte count', () {
      final buffer = PcmBuffer.silent(sampleRate: 22050, seconds: 0.1);
      final bytes = encodeWavMono16(buffer);
      final view = ByteData.view(bytes.buffer);

      final dataBytes = view.getUint32(40, Endian.little);
      final riffBytes = view.getUint32(4, Endian.little);

      expect(dataBytes, buffer.frameCount * 2);
      expect(bytes.length, 44 + dataBytes);
      expect(riffBytes, bytes.length - 8);
    });

    test('full scale does not wrap around', () {
      final bytes = encodeWavMono16(
        PcmBuffer(
          sampleRate: 1000,
          samples: Float32List.fromList([1.0, -1.0, 0.0, 2.0, -2.0]),
        ),
      );
      final view = ByteData.view(bytes.buffer);

      expect(view.getInt16(44, Endian.little), 32767);
      expect(view.getInt16(46, Endian.little), -32767);
      expect(view.getInt16(48, Endian.little), 0);
      expect(view.getInt16(50, Endian.little), 32767, reason: 'clamped');
      expect(view.getInt16(52, Endian.little), -32767, reason: 'clamped');
    });
  });

  group('Music', () {
    test('the grid is whole samples and the tempo lands close to asked', () {
      const config = MusicConfig.standard;

      expect(
        config.totalSamples,
        config.totalSteps * config.samplesPerStep,
        reason: 'the loop must be an exact number of steps, or layers drift',
      );
      expect(
        config.effectiveBeatsPerMinute,
        closeTo(config.beatsPerMinute.toDouble(), 0.5),
        reason: 'rounding the step may shift the tempo, but only slightly',
      );
    });

    test('every layer is the same length', () {
      final renderer = MusicRenderer();
      final lengths = <int>{
        for (final layer in MusicLayer.values)
          renderer.renderLayer(layer).frameCount,
      };

      expect(lengths.length, 1, reason: 'layers differ in length: $lengths');
      expect(lengths.single, MusicConfig.standard.totalSamples);
    });

    test('every layer is audible, finite and within full scale', () {
      final renderer = MusicRenderer();

      for (final layer in MusicLayer.values) {
        final buffer = renderer.renderLayer(layer);

        for (var i = 0; i < buffer.frameCount; i++) {
          final sample = buffer.samples[i];
          expect(sample.isFinite, isTrue, reason: '$layer sample $i');
          expect(sample.abs(), lessThanOrEqualTo(1.0), reason: '$layer at $i');
        }
        expect(buffer.peak(), greaterThan(0.5), reason: '$layer is too quiet');
      }
    });

    test('every layer joins seamlessly at the loop point', () {
      final renderer = MusicRenderer();

      for (final layer in MusicLayer.values) {
        final samples = renderer.renderLayer(layer).samples;

        var largestInternalStep = 0.0;
        for (var i = 1; i < samples.length; i++) {
          final delta = (samples[i] - samples[i - 1]).abs();
          if (delta > largestInternalStep) largestInternalStep = delta;
        }
        final seamStep = (samples.first - samples.last).abs();

        expect(
          seamStep,
          lessThanOrEqualTo(largestInternalStep),
          reason: '$layer steps harder across the loop point than anywhere '
              'inside it, so it will click once per loop',
        );
      }
    });

    test('layers join as intensity rises and never un-join', () {
      for (final layer in MusicLayer.values) {
        var previous = 0.0;
        for (var intensity = 0; intensity <= 6; intensity++) {
          final volume = layer.volumeAt(intensity);
          expect(volume, greaterThanOrEqualTo(previous), reason: '$layer');
          previous = volume;
        }
        expect(layer.volumeAt(0) > 0.0, layer.joinsAtIntensity == 0);
        expect(layer.volumeAt(99), layer.mixGain);
      }
    });

    test('the drums carry the menu on their own', () {
      final audible = MusicLayer.values
          .where((layer) => layer.volumeAt(0) > 0.0)
          .toList();

      expect(audible, <MusicLayer>[MusicLayer.drums]);
    });

    test('rendering is reproducible for a given seed', () {
      final first = MusicRenderer(noiseSeed: 77).renderLayer(MusicLayer.drums);
      final second = MusicRenderer(noiseSeed: 77).renderLayer(MusicLayer.drums);

      expect(second.samples, first.samples);
    });

    test('the bank holds playable bytes for every layer', () {
      final bank = MusicBank.render();

      for (final layer in MusicLayer.values) {
        final wav = bank.wavFor(layer);
        expect(wav.length, greaterThan(44), reason: '$layer has no samples');
        expect(_ascii(wav, 0, 4), 'RIFF', reason: '$layer is not a WAV');
      }
    });

    test('the bank survives a round trip through raw bytes', () {
      final original = MusicBank.render();
      final bytes = <Uint8List>[
        for (final layer in MusicLayer.values) original.wavFor(layer),
      ];

      final rebuilt = MusicBank.fromWavBytes(bytes);

      for (final layer in MusicLayer.values) {
        expect(rebuilt.wavFor(layer), original.wavFor(layer));
      }
    });

    test('rebuilding from the wrong number of layers is rejected', () {
      expect(
        () => MusicBank.fromWavBytes(<Uint8List>[Uint8List(0)]),
        throwsArgumentError,
      );
    });

    test('the soundtrack stays inside its memory budget', () {
      final bank = MusicBank.render();

      expect(bank.totalBytes, lessThan(4 * 1024 * 1024));
    });
  });
}

String _ascii(Uint8List bytes, int offset, int length) =>
    String.fromCharCodes(bytes.sublist(offset, offset + length));

double _filteredEnergy(double frequencyHz, double cutoffHz, int sampleRate) {
  final filter = OnePoleLowPass(sampleRate);
  var phase = 0.0;
  var energy = 0.0;

  for (var i = 0; i < sampleRate ~/ 10; i++) {
    final output = filter.process(sineAt(phase), cutoffHz);
    energy += output * output;
    phase = advancePhase(phase, frequencyHz, sampleRate);
  }
  return energy;
}
