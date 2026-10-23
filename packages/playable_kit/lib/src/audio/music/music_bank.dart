import 'dart:typed_data';

import 'music_voice.dart';
import '../wav_encoder.dart';
import 'music_layer.dart';
import 'music_renderer.dart';

class MusicBank {
  const MusicBank._(this._wavByLayer);

  factory MusicBank.render({
    MusicVoice voice = MusicRenderer.defaultVoice,
    MusicConfig? config,
    int noiseSeed = MusicRenderer.defaultNoiseSeed,
  }) {
    final renderer = MusicRenderer(
      voice: voice,
      config: config,
      noiseSeed: noiseSeed,
    );
    const layers = MusicLayer.values;

    return MusicBank._(
      List<Uint8List>.generate(
        layers.length,
        (index) => encodeWavMono16(renderer.renderLayer(layers[index])),
        growable: false,
      ),
    );
  }

  factory MusicBank.fromWavBytes(List<Uint8List> wavByLayer) {
    if (wavByLayer.length != MusicLayer.values.length) {
      throw ArgumentError.value(
        wavByLayer.length,
        'wavByLayer',
        'expected one entry per MusicLayer '
            '(${MusicLayer.values.length})',
      );
    }
    return MusicBank._(List<Uint8List>.unmodifiable(wavByLayer));
  }

  static List<Uint8List> renderWavBytes({
    MusicVoice voice = MusicRenderer.defaultVoice,
  }) =>
      MusicBank.render(voice: voice)._wavByLayer;

  final List<Uint8List> _wavByLayer;

  Uint8List wavFor(MusicLayer layer) => _wavByLayer[layer.index];

  int get totalBytes {
    var total = 0;
    for (var i = 0; i < _wavByLayer.length; i++) {
      total += _wavByLayer[i].length;
    }
    return total;
  }
}
