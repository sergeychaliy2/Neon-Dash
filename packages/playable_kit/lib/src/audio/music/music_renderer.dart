import 'dart:typed_data';

import '../../random/deterministic_random.dart';
import 'music_voice.dart';
import '../pcm_buffer.dart';
import 'instruments.dart';
import 'music_layer.dart';

class MusicConfig {
  const MusicConfig({
    required this.sampleRate,
    required this.beatsPerMinute,
    required this.stepsPerBeat,
    required this.beatsPerBar,
    required this.bars,
  });

  final int sampleRate;

  final int beatsPerMinute;
  final int stepsPerBeat;
  final int beatsPerBar;
  final int bars;

  MusicConfig withTempo(int beatsPerMinute) => MusicConfig(
        sampleRate: sampleRate,
        beatsPerMinute: beatsPerMinute,
        stepsPerBeat: stepsPerBeat,
        beatsPerBar: beatsPerBar,
        bars: bars,
      );

  int get stepsPerBar => beatsPerBar * stepsPerBeat;
  int get totalSteps => bars * stepsPerBar;

  int get samplesPerStep =>
      (sampleRate * 60 / (beatsPerMinute * stepsPerBeat)).round();

  int get totalSamples => totalSteps * samplesPerStep;

  double get stepSeconds => samplesPerStep / sampleRate;

  double get effectiveBeatsPerMinute =>
      sampleRate * 60 / (samplesPerStep * stepsPerBeat);

  static const MusicConfig standard = MusicConfig(
    sampleRate: 32000,
    beatsPerMinute: 140,
    stepsPerBeat: 4,
    beatsPerBar: 4,
    bars: 8,
  );
}

class MusicRenderer {
  MusicRenderer({
    MusicVoice voice = defaultVoice,
    MusicConfig? config,
    int noiseSeed = defaultNoiseSeed,
  })  : _voice = voice,
        config = config ?? MusicConfig.standard.withTempo(voice.beatsPerMinute),
        _noise = DeterministicRandom(noiseSeed);

  static const MusicVoice defaultVoice = MusicVoice(
    beatsPerMinute: 140,
    rootSemitone: 0.0,
    progression: <int>[0, 8, 3, 10],
    minorChords: <bool>[true, false, false, false],
    leadOctave: 0.0,
    groove: MusicGroove.pulse,
    style: MusicStyle.pulse,
  );

  static const int defaultNoiseSeed = 0x7A1B;

  static const double _layerPeak = 0.9;

  static const int _fillOctave = 12;

  static const double _timingHumanise = 0.055;

  static const double _velocityHumanise = 0.18;

  static const List<double> _fillPitches = <double>[220.0, 165.0, 124.0];

  static const double _riserBars = 2.0;

  static const List<int> _minorTones = <int>[0, 3, 7, 12];
  static const List<int> _majorTones = <int>[0, 4, 7, 12];

  static const List<int> _leadRising = <int>[0, 2, 1, 3];
  static const List<int> _leadFalling = <int>[3, 1, 2, 0];

  static const double _bassOctave = -24.0;
  static const double _arpOctave = -12.0;

  final MusicConfig config;
  final MusicVoice _voice;
  final DeterministicRandom _noise;

  MusicStyle get _style => _voice.style;

  MusicVoice get voice => _voice;

  PcmBuffer renderLayer(MusicLayer layer) {
    final samples = Float32List(config.totalSamples);

    switch (layer) {
      case MusicLayer.drums:
        _renderDrums(samples);
      case MusicLayer.bass:
        _renderBass(samples);
      case MusicLayer.arp:
        _renderArp(samples);
      case MusicLayer.lead:
        _renderLead(samples);
    }

    final buffer = PcmBuffer(sampleRate: config.sampleRate, samples: samples);
    buffer.normalizeTo(_layerPeak);
    return buffer;
  }

  void _renderDrums(Float32List out) {
    final groove = _voice.groove;
    final lastBar = config.bars - 1;
    final fillFrom = lastBar * config.stepsPerBar +
        (config.beatsPerBar - 1) * config.stepsPerBeat;

    _renderRiser(out);

    for (var step = 0; step < config.totalSteps; step++) {
      final inBar = step % config.stepsPerBar;
      final at = _sampleOf(step, human: false);

      if (step >= fillFrom) {
        _renderFillStep(out, step, fillFrom);
        continue;
      }

      if (groove.kick[inBar] == 'x') {
        renderKick(
          out: out,
          startSample: at,
          sampleRate: config.sampleRate,
          gain: 1.0,
        );
      }
      if (groove.clap[inBar] == 'x') {
        renderClap(
          out: out,
          startSample: at,
          sampleRate: config.sampleRate,
          gain: 0.5 * _velocity,
          noise: _noise,
        );
      }

      final hat = groove.hat[inBar];
      if (hat != '.') {
        renderHat(
          out: out,
          startSample: at,
          sampleRate: config.sampleRate,
          gain: (inBar.isEven ? 0.3 : 0.2) * _velocity,
          open: hat == 'o',
          noise: _noise,
        );
      }
    }
  }

  void _renderFillStep(Float32List out, int step, int fillFrom) {
    final into = step - fillFrom;
    if (into.isOdd) return;

    final index = (into ~/ 2) % _fillPitches.length;
    renderTom(
      out: out,
      startSample: _sampleOf(step),
      sampleRate: config.sampleRate,
      pitchHz: _fillPitches[index],
      gain: 0.55 + 0.12 * index,
    );
  }

  void _renderRiser(Float32List out) {
    final steps = (_riserBars * config.stepsPerBar).round();
    final startStep = config.totalSteps - steps;
    if (startStep < 0) return;

    renderRiser(
      out: out,
      startSample: startStep * config.samplesPerStep,
      sampleRate: config.sampleRate,
      seconds: steps * config.stepSeconds,
      gain: 0.22,
      noise: _noise,
    );
  }

  int _sampleOf(int step, {bool human = true}) {
    var at = step * config.samplesPerStep;
    if (step.isOdd) {
      at += (config.samplesPerStep * _voice.groove.swing).round();
    }
    if (!human) return at;

    final drift = _noise.nextRange(-_timingHumanise, _timingHumanise);
    at += (config.samplesPerStep * drift).round();
    return at < 0 ? 0 : at;
  }

  double get _velocity =>
      1.0 + _noise.nextRange(-_velocityHumanise, _velocityHumanise);

  void _renderBass(Float32List out) {
    final noteSeconds = config.stepSeconds * 1.9;
    final figure = _style.bass.steps;
    final halfway = config.bars ~/ 2;

    for (var step = 0; step < config.totalSteps; step++) {
      final bar = step ~/ config.stepsPerBar;
      final inBar = step % config.stepsPerBar;
      var offset = figure[inBar];

      if (offset < 0) {
        if (bar < halfway || inBar.isOdd) continue;
        offset = _fillOctave;
      }

      renderBass(
        out: out,
        startSample: _sampleOf(step),
        sampleRate: config.sampleRate,
        frequencyHz: frequencyOfSemitone(
          _bassOctave + _chordRoot(bar) + offset,
        ),
        seconds: noteSeconds * (0.85 + _noise.nextDouble() * 0.3),
        gain: (inBar == 0 ? 1.0 : 0.82) * _velocity,
      );
    }
  }

  void _renderArp(Float32List out) {
    final noteSeconds = config.stepSeconds * 1.6;

    for (var step = 0; step < config.totalSteps; step++) {
      final bar = step ~/ config.stepsPerBar;
      final inBar = step % config.stepsPerBar;
      final tones = _chordTones(bar);

      if (_style.arp == ArpShape.stab) {
        if (inBar % 4 != 2) continue;
        for (final tone in tones) {
          renderPluck(
            out: out,
            startSample: _sampleOf(step),
            sampleRate: config.sampleRate,
            frequencyHz: frequencyOfSemitone(
              _arpOctave + _chordRoot(bar) + tone,
            ),
            seconds: noteSeconds,
            gain: 0.34 * _velocity,
          );
        }
        continue;
      }

      final (tone, octave) = _arpNote(tones, bar, inBar);

      renderPluck(
        out: out,
        startSample: _sampleOf(step),
        sampleRate: config.sampleRate,
        frequencyHz: frequencyOfSemitone(
          _arpOctave + _chordRoot(bar) + tone + octave,
        ),
        seconds: noteSeconds,
        gain: 0.55 * _velocity,
      );
    }
  }

  (int, int) _arpNote(List<int> tones, int bar, int inBar) {
    final place = inBar % tones.length;
    final lap = inBar ~/ tones.length;
    final octave = lap.isOdd ? 12 : 0;

    return switch (_style.arp) {
      ArpShape.climb => (tones[place], octave),
      ArpShape.fall => (tones[tones.length - 1 - place], octave),
      ArpShape.pendulum => (
          tones[lap.isOdd ? tones.length - 1 - place : place],
          0,
        ),
      ArpShape.octaves => (
          tones[place.isEven ? 0 : 2 % tones.length],
          place.isEven ? 0 : 12,
        ),
      ArpShape.walk => (
          tones[(place * 3 + bar) % tones.length],
          (place + bar).isOdd ? 12 : 0,
        ),
      ArpShape.stab => (tones[place], octave),
    };
  }

  void _renderLead(Float32List out) {
    final stepsPerEighth = config.stepsPerBeat ~/ 2;
    if (stepsPerEighth <= 0) return;

    final eighthsPerBar = config.stepsPerBar ~/ stepsPerEighth;
    final noteSeconds = config.stepSeconds * stepsPerEighth * 1.7;
    final lastBar = config.bars - 1;

    for (var bar = 0; bar < config.bars; bar++) {
      final tones = _chordTones(bar);
      final shape = bar.isEven ? _leadRising : _leadFalling;
      final rhythm =
          _style.phrasing.bars[bar % _style.phrasing.bars.length];
      var hit = 0;

      for (var eighth = 0; eighth < eighthsPerBar; eighth++) {
        if (rhythm[eighth % rhythm.length] != 'x') continue;

        final step = bar * config.stepsPerBar + eighth * stepsPerEighth;
        final resolving = bar == lastBar && hit > 0;
        final tone = resolving ? 0 : tones[shape[hit % shape.length]];
        hit++;

        _renderLeadNote(
          out: out,
          startSample: _sampleOf(step),
          frequencyHz: frequencyOfSemitone(
            _voice.leadOctave + _chordRoot(bar) + tone,
          ),
          seconds: resolving ? noteSeconds * 2.4 : noteSeconds,
          gain: (resolving ? 0.78 : 0.7) * _velocity,
        );
      }
    }
  }

  void _renderLeadNote({
    required Float32List out,
    required int startSample,
    required double frequencyHz,
    required double seconds,
    required double gain,
  }) {
    switch (_style.voice) {
      case LeadVoice.sustained:
        renderLead(
          out: out,
          startSample: startSample,
          sampleRate: config.sampleRate,
          frequencyHz: frequencyHz,
          seconds: seconds,
          gain: gain,
        );
      case LeadVoice.bell:
        renderBell(
          out: out,
          startSample: startSample,
          sampleRate: config.sampleRate,
          frequencyHz: frequencyHz,
          seconds: seconds * 1.6,
          gain: gain * 0.9,
        );
      case LeadVoice.pluck:
        renderPluck(
          out: out,
          startSample: startSample,
          sampleRate: config.sampleRate,
          frequencyHz: frequencyHz * 2.0,
          seconds: seconds * 0.8,
          gain: gain * 0.85,
        );
    }
  }

  int _chordIndex(int bar) =>
      (bar ~/ _style.barsPerChord) % _voice.progression.length;

  double _chordRoot(int bar) =>
      _voice.rootSemitone + _voice.progression[_chordIndex(bar)];

  List<int> _chordTones(int bar) {
    final index = _chordIndex(bar);
    final minor = index < _voice.minorChords.length
        ? _voice.minorChords[index]
        : false;
    return minor ? _minorTones : _majorTones;
  }
}
