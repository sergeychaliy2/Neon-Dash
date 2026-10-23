import 'dart:typed_data';

import 'package:playable_kit/playable_kit.dart';

import '../domain/game_event.dart';
import 'cue_synth.dart';
import 'sound_cue.dart';

class SoundBank {
  SoundBank._(this._wavByCueIndex, this.sampleRate);

  factory SoundBank.render({
    int sampleRate = CueSynth.defaultSampleRate,
    int noiseSeed = CueSynth.defaultNoiseSeed,
  }) {
    final synth = CueSynth(sampleRate: sampleRate, noiseSeed: noiseSeed);
    const cues = SoundCue.values;
    final encoded = List<Uint8List>.generate(
      cues.length,
      (index) => encodeWavMono16(synth.render(cues[index])),
      growable: false,
    );
    return SoundBank._(encoded, sampleRate);
  }

  factory SoundBank.fromWavBytes(
    List<Uint8List> wavByCue, {
    int sampleRate = CueSynth.defaultSampleRate,
  }) {
    if (wavByCue.length != SoundCue.values.length) {
      throw ArgumentError.value(
        wavByCue.length,
        'wavByCue',
        'expected one entry per SoundCue (${SoundCue.values.length})',
      );
    }
    return SoundBank._(List<Uint8List>.unmodifiable(wavByCue), sampleRate);
  }

  static List<Uint8List> renderWavBytes() => SoundBank.render()._wavByCueIndex;

  final List<Uint8List> _wavByCueIndex;

  final int sampleRate;

  Uint8List wavFor(SoundCue cue) => _wavByCueIndex[cue.index];

  Uint8List wavForEvent(GameEvent event) => wavFor(cueForEvent(event));

  int get totalBytes {
    var total = 0;
    for (var i = 0; i < _wavByCueIndex.length; i++) {
      total += _wavByCueIndex[i].length;
    }
    return total;
  }
}
