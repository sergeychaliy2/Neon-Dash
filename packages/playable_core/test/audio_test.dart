import 'dart:typed_data';

import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';
import 'package:test/test.dart';

void main() {
  group('Cue synthesis', () {
    test('every cue is audible, finite and within full scale', () {
      final synth = CueSynth();

      for (final cue in SoundCue.values) {
        final buffer = synth.render(cue);
        expect(buffer.frameCount, greaterThan(0), reason: '$cue is empty');

        for (var i = 0; i < buffer.frameCount; i++) {
          final sample = buffer.samples[i];
          expect(sample.isFinite, isTrue, reason: '$cue sample $i is not finite');
          expect(sample.abs(), lessThanOrEqualTo(1.0), reason: '$cue sample $i');
        }

        expect(
          buffer.peak(),
          greaterThan(0.25),
          reason: '$cue is too quiet to hear',
        );
      }
    });

    test('one-shots are short enough not to overlap gameplay', () {
      final synth = CueSynth();

      for (final cue in SoundCue.values) {
        expect(
          synth.render(cue).durationSeconds,
          lessThanOrEqualTo(1.0),
          reason: '$cue is too long for a gameplay cue',
        );
      }
    });

    test('rendering is reproducible for a given seed', () {
      final first = CueSynth(noiseSeed: 4242).render(SoundCue.crash);
      final second = CueSynth(noiseSeed: 4242).render(SoundCue.crash);

      expect(second.samples, first.samples);
    });

    test('a different noise seed changes a noise-based cue', () {
      final first = CueSynth(noiseSeed: 1).render(SoundCue.crash);
      final second = CueSynth(noiseSeed: 2).render(SoundCue.crash);

      expect(second.samples, isNot(first.samples));
    });
  });

  group('SoundBank', () {
    test('holds playable bytes for every cue', () {
      final bank = SoundBank.render();

      for (final cue in SoundCue.values) {
        final wav = bank.wavFor(cue);
        expect(wav.length, greaterThan(44), reason: '$cue has no samples');
        expect(_ascii(wav, 0, 4), 'RIFF', reason: '$cue is not a WAV');
      }
    });

    test('maps every game event to a cue', () {
      final bank = SoundBank.render();

      for (final event in GameEvent.values) {
        expect(
          bank.wavForEvent(event),
          same(bank.wavFor(cueForEvent(event))),
          reason: '$event must resolve to its cue without copying',
        );
      }
    });

    test('event to cue mapping is the intended one', () {
      expect(cueForEvent(GameEvent.runStarted), SoundCue.runStart);
      expect(cueForEvent(GameEvent.nearMiss), SoundCue.nearMiss);
      expect(cueForEvent(GameEvent.orbCollected), SoundCue.orbPickup);
      expect(cueForEvent(GameEvent.speedTierUp), SoundCue.speedUp);
      expect(cueForEvent(GameEvent.crashed), SoundCue.crash);
    });

    test('rendering twice with the same seed gives identical bytes', () {
      final first = SoundBank.render(noiseSeed: 9);
      final second = SoundBank.render(noiseSeed: 9);

      for (final cue in SoundCue.values) {
        expect(second.wavFor(cue), first.wavFor(cue), reason: '$cue differs');
      }
    });

    test('the whole bank stays inside its memory budget', () {
      final bank = SoundBank.render();

      expect(bank.totalBytes, lessThan(512 * 1024));
    });
  });

  group('Per-level music', () {
    test('every level gets its own tempo grid', () {
      for (final level in LevelCatalogue.levels) {
        final renderer = MusicRenderer(voice: level.music);

        expect(
          renderer.config.effectiveBeatsPerMinute,
          closeTo(level.music.beatsPerMinute.toDouble(), 1.0),
          reason: level.name,
        );
      }
    });

    test('every level has the same number of samples to loop', () {
      final lengths = <int>{
        for (final level in LevelCatalogue.levels)
          MusicRenderer(voice: level.music)
              .renderLayer(MusicLayer.drums)
              .samples
              .length,
      };

      expect(lengths.length, greaterThan(1),
          reason: 'tempo does change the sample count');
      for (final level in LevelCatalogue.levels) {
        final renderer = MusicRenderer(voice: level.music);
        final drums = renderer.renderLayer(MusicLayer.drums).samples.length;
        for (final layer in MusicLayer.values) {
          expect(renderer.renderLayer(layer).samples.length, drums,
              reason: '${level.name} ${layer.name}');
        }
      }
    });

    test('no two levels render the same drum track', () {
      final seen = <String, String>{};

      for (final level in LevelCatalogue.levels) {
        final samples =
            MusicRenderer(voice: level.music).renderLayer(MusicLayer.drums);
        final signature = _signature(samples);

        expect(seen.containsKey(signature), isFalse,
            reason: '${level.name} sounds identical to ${seen[signature]}');
        seen[signature] = level.name;
      }
    });

    test('no two levels render the same lead line', () {
      final seen = <String, String>{};

      for (final level in LevelCatalogue.levels) {
        final samples =
            MusicRenderer(voice: level.music).renderLayer(MusicLayer.lead);
        final signature = _signature(samples);

        expect(seen.containsKey(signature), isFalse,
            reason: '${level.name} sounds identical to ${seen[signature]}');
        seen[signature] = level.name;
      }
    });

    test('every groove hits something on every instrument', () {
      for (final groove in MusicGroove.values) {
        expect(groove.kick, contains('x'), reason: groove.name);
        expect(groove.clap, contains('x'), reason: groove.name);
        expect(groove.hat, matches(RegExp('[xo]')), reason: groove.name);
      }
    });

    test('every groove is exactly one bar of sixteenths', () {
      const stepsPerBar = 16;
      for (final groove in MusicGroove.values) {
        expect(groove.kick.length, stepsPerBar, reason: groove.name);
        expect(groove.clap.length, stepsPerBar, reason: groove.name);
        expect(groove.hat.length, stepsPerBar, reason: groove.name);
      }
    });

    test('a groove uses only the notation the renderer understands', () {
      final allowed = RegExp(r'^[xo.]+$');
      for (final groove in MusicGroove.values) {
        expect(allowed.hasMatch(groove.kick), isTrue, reason: groove.name);
        expect(allowed.hasMatch(groove.clap), isTrue, reason: groove.name);
        expect(allowed.hasMatch(groove.hat), isTrue, reason: groove.name);
      }
    });

    test('a level bank is playable and reproducible', () {
      final level = LevelCatalogue.byIndex(4);
      final first = MusicBank.render(voice: level.music);
      final second = MusicBank.render(voice: level.music);

      for (final layer in MusicLayer.values) {
        expect(first.wavFor(layer), second.wavFor(layer), reason: layer.name);
        expect(first.wavFor(layer).length, greaterThan(44));
      }
    });

    test('a groove states how much it swings, within reason', () {
      for (final groove in MusicGroove.values) {
        expect(groove.swing, greaterThanOrEqualTo(0.0), reason: groove.name);
        expect(groove.swing, lessThan(0.34),
            reason: '${groove.name}: past a third of a step the off-beat '
                'lands on the next one');
      }
    });

    test('swing moves the off-beats and leaves the pulse alone', () {
      const straight = MusicVoice(
        beatsPerMinute: 140,
        rootSemitone: 0.0,
        progression: <int>[0, 5],
        minorChords: <bool>[true, false],
        leadOctave: 0.0,
        groove: MusicGroove.pulse,
        style: MusicStyle.pulse,
      );
      const swung = MusicVoice(
        beatsPerMinute: 140,
        rootSemitone: 0.0,
        progression: <int>[0, 5],
        minorChords: <bool>[true, false],
        leadOctave: 0.0,
        groove: MusicGroove.breaks,
        style: MusicStyle.fracture,
      );

      final a = MusicRenderer(voice: straight).renderLayer(MusicLayer.bass);
      final b = MusicRenderer(voice: swung).renderLayer(MusicLayer.bass);

      expect(a.samples.length, b.samples.length, reason: 'same tempo');
      expect(_signature(a), isNot(_signature(b)));
    });

    test('the loop climbs into its own first beat', () {
      final drums = MusicRenderer(voice: MusicRenderer.defaultVoice)
          .renderLayer(MusicLayer.drums);
      final samples = drums.samples;

      int brightnessOfBar(int bar) {
        final size = samples.length ~/ 8;
        var crossings = 0;
        for (var i = bar * size + 1; i < (bar + 1) * size; i++) {
          if ((samples[i] < 0.0) != (samples[i - 1] < 0.0)) crossings++;
        }
        return crossings;
      }

      expect(
        brightnessOfBar(7),
        greaterThan(brightnessOfBar(3)),
        reason: 'the last bar should be sweeping upward',
      );
    });

    test('the loop does not simply repeat one bar eight times', () {
      final drums = MusicRenderer(voice: MusicRenderer.defaultVoice)
          .renderLayer(MusicLayer.drums);
      final bass = MusicRenderer(voice: MusicRenderer.defaultVoice)
          .renderLayer(MusicLayer.bass);

      String half(PcmBuffer buffer, int index) {
        final size = buffer.samples.length ~/ 2;
        var energy = 0.0;
        var crossings = 0;
        for (var i = index * size + 1; i < (index + 1) * size; i++) {
          energy += buffer.samples[i] * buffer.samples[i];
          if ((buffer.samples[i] < 0.0) != (buffer.samples[i - 1] < 0.0)) {
            crossings++;
          }
        }
        return '${(energy * 100).round()}/$crossings';
      }

      expect(half(drums, 0), isNot(half(drums, 1)));
      expect(half(bass, 0), isNot(half(bass, 1)),
          reason: 'the back half runs the busier bass figure');
    });

    test('every arrangement style is used by some level', () {
      final used = <MusicStyle>{
        for (final level in LevelCatalogue.levels) level.music.style,
      };

      expect(used, hasLength(MusicStyle.values.length));
    });

    test('no two levels in a row share an arrangement', () {
      for (var i = 1; i < LevelCatalogue.count; i++) {
        expect(
          LevelCatalogue.byIndex(i).music.style,
          isNot(LevelCatalogue.byIndex(i - 1).music.style),
          reason: LevelCatalogue.byIndex(i).name,
        );
      }
    });

    test('every bass figure plays something, and fits one bar', () {
      for (final figure in BassFigure.values) {
        expect(figure.steps, hasLength(16), reason: figure.name);
        expect(figure.steps.any((step) => step >= 0), isTrue,
            reason: '${figure.name} is silent');
      }
    });

    test('every phrasing has four bars that between them play notes', () {
      for (final phrasing in LeadPhrasing.values) {
        expect(phrasing.bars, hasLength(4), reason: phrasing.name);
        for (final bar in phrasing.bars) {
          expect(bar.length, 8, reason: phrasing.name);
          expect(RegExp(r'^[x.]+$').hasMatch(bar), isTrue,
              reason: phrasing.name);
        }
        expect(phrasing.bars.any((bar) => bar.contains('x')), isTrue,
            reason: '${phrasing.name} never plays');
      }
    });

    test('two styles on the same voice render differently', () {
      MusicVoice voiceWith(MusicStyle style) => MusicVoice(
            beatsPerMinute: 140,
            rootSemitone: 0.0,
            progression: const <int>[0, 8, 3, 10],
            minorChords: const <bool>[true, false, false, false],
            leadOctave: 0.0,
            groove: MusicGroove.pulse,
            style: style,
          );

      for (final layer in <MusicLayer>[
        MusicLayer.bass,
        MusicLayer.arp,
        MusicLayer.lead,
      ]) {
        final seen = <String, String>{};
        for (final style in MusicStyle.values) {
          final rendered =
              MusicRenderer(voice: voiceWith(style)).renderLayer(layer);
          final signature = _signature(rendered);

          expect(seen.containsKey(signature), isFalse,
              reason: '${layer.name}: ${style.name} is identical to '
                  '${seen[signature]}');
          seen[signature] = style.name;
        }
      }
    });

    test('humanising moves notes without moving the tempo', () {
      final first = MusicRenderer(voice: MusicRenderer.defaultVoice)
          .renderLayer(MusicLayer.bass);
      final second = MusicRenderer(voice: MusicRenderer.defaultVoice)
          .renderLayer(MusicLayer.bass);

      expect(_signature(first), _signature(second));
      expect(first.samples.length, second.samples.length);
    });

    test('the kick stays exactly on the grid', () {
      const voice = MusicVoice(
        beatsPerMinute: 120,
        rootSemitone: 0.0,
        progression: <int>[0],
        minorChords: <bool>[true],
        leadOctave: 0.0,
        groove: MusicGroove.halftime,
        style: MusicStyle.pulse,
      );

      final drums = MusicRenderer(voice: voice).renderLayer(MusicLayer.drums);

      var firstLoud = drums.samples.length;
      for (var i = 0; i < drums.samples.length; i++) {
        if (drums.samples[i].abs() > 0.05) {
          firstLoud = i;
          break;
        }
      }
      expect(firstLoud, lessThan(64));
    });

    test('a voice whose chord lists disagree still renders', () {
      const lopsided = MusicVoice(
        beatsPerMinute: 140,
        rootSemitone: 2.0,
        progression: <int>[0, 5, 7, 9],
        minorChords: <bool>[true],
        leadOctave: 0.0,
        groove: MusicGroove.pulse,
        style: MusicStyle.pulse,
      );

      final rendered = MusicRenderer(voice: lopsided).renderLayer(
        MusicLayer.arp,
      );

      expect(rendered.samples.length, greaterThan(0));
      for (final sample in rendered.samples) {
        expect(sample.isFinite, isTrue);
      }
    });
  });

}

String _signature(PcmBuffer buffer) {
  const buckets = 8;
  final samples = buffer.samples;
  final size = samples.length ~/ buckets;
  final parts = <String>[];

  for (var b = 0; b < buckets; b++) {
    final from = b * size;
    final to = from + size;

    var energy = 0.0;
    var crossings = 0;
    for (var i = from; i < to; i++) {
      energy += samples[i] * samples[i];
      if (i > from && (samples[i] < 0.0) != (samples[i - 1] < 0.0)) {
        crossings++;
      }
    }

    parts.add('${(energy / size * 1000).round()}/$crossings');
  }
  return parts.join(':');
}

String _ascii(Uint8List bytes, int offset, int length) =>
    String.fromCharCodes(bytes.sublist(offset, offset + length));
