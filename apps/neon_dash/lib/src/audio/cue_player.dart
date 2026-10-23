import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';

abstract interface class CuePlayer {
  bool get isAudible;

  void play(SoundCue cue);

  void startMusic();

  Future<void> loadMusic(MusicBank music, {required String tag});

  void setMusicIntensity(int intensity);

  void setMusicVolume(double volume);

  void setEffectsVolume(double volume);

  void setMusicPaused(bool paused);

  Future<void> dispose();
}

Future<CuePlayer> createCuePlayer({
  required SoundBank cues,
  required MusicBank music,
  String musicTag = 'menu',
}) async {
  final player = _SoLoudCuePlayer(
    cues: cues,
    music: music,
    musicTag: musicTag,
  );
  try {
    await player.start();
    return player;
  } on Object catch (error, stackTrace) {
    debugPrint('neon_dash: audio unavailable, continuing silently — $error');
    debugPrintStack(stackTrace: stackTrace);
    await player.dispose();
    return const SilentCuePlayer();
  }
}

class SilentCuePlayer implements CuePlayer {
  const SilentCuePlayer();

  @override
  bool get isAudible => false;

  @override
  void play(SoundCue cue) {}

  @override
  void startMusic() {}

  @override
  Future<void> loadMusic(MusicBank music, {required String tag}) async {}

  @override
  void setMusicIntensity(int intensity) {}

  @override
  void setMusicVolume(double volume) {}

  @override
  void setEffectsVolume(double volume) {}

  @override
  void setMusicPaused(bool paused) {}

  @override
  Future<void> dispose() async {}
}

class _SoLoudCuePlayer implements CuePlayer {
  _SoLoudCuePlayer({
    required SoundBank cues,
    required MusicBank music,
    required String musicTag,
  })
      // ignore: prefer_initializing_formals
      : _cues = cues,
        // ignore: prefer_initializing_formals
        _music = music,
        // ignore: prefer_initializing_formals
        _musicTag = musicTag,
        _cueSources = List<AudioSource?>.filled(SoundCue.values.length, null),
        _layerSources =
            List<AudioSource?>.filled(MusicLayer.values.length, null),
        _layerHandles =
            List<SoundHandle?>.filled(MusicLayer.values.length, null);

  static const Duration _layerFade = Duration(milliseconds: 700);

  static const Duration _volumeFade = Duration(milliseconds: 120);

  final SoundBank _cues;
  MusicBank _music;
  String _musicTag;

  final List<AudioSource?> _cueSources;
  final List<AudioSource?> _layerSources;
  final List<SoundHandle?> _layerHandles;

  SoundHandle? _musicGroup;
  bool _musicStarting = false;
  int _intensity = 0;
  bool _ready = false;

  double _musicVolume = 1.0;
  double _effectsVolume = 1.0;

  @override
  bool get isAudible => _ready;

  Future<void> start() async {
    final soloud = SoLoud.instance;
    if (!soloud.isInitialized) {
      await soloud.init();
    }

    for (final cue in SoundCue.values) {
      _cueSources[cue.index] = await soloud.loadMem(
        '${cue.name}.wav',
        _cues.wavFor(cue),
      );
    }
    await _uploadMusic();

    _ready = true;
  }

  Future<void> _uploadMusic() async {
    final soloud = SoLoud.instance;
    for (final layer in MusicLayer.values) {
      _layerSources[layer.index] = await soloud.loadMem(
        'music_${_musicTag}_${layer.name}.wav',
        _music.wavFor(layer),
      );
    }
  }

  @override
  void play(SoundCue cue) {
    if (!_ready || _effectsVolume <= 0.0) return;
    final source = _cueSources[cue.index];
    if (source == null) return;
    unawaited(
      _guard(() => SoLoud.instance.play(source, volume: _effectsVolume)),
    );
  }

  @override
  void setEffectsVolume(double volume) {
    _effectsVolume = _clampVolume(volume);
  }

  @override
  void setMusicVolume(double volume) {
    final level = _clampVolume(volume);
    if (level == _musicVolume) return;
    _musicVolume = level;
    if (!_ready) return;

    final soloud = SoLoud.instance;
    for (final layer in MusicLayer.values) {
      final handle = _layerHandles[layer.index];
      if (handle == null) continue;
      soloud.fadeVolume(handle, _volumeOf(layer), _volumeFade);
    }
  }

  double _volumeOf(MusicLayer layer) =>
      layer.volumeAt(_intensity) * _musicVolume;

  static double _clampVolume(double volume) {
    if (!volume.isFinite) return 1.0;
    if (volume < 0.0) return 0.0;
    return volume > 1.0 ? 1.0 : volume;
  }

  @override
  void startMusic() {
    if (!_ready || _musicGroup != null || _musicStarting) return;
    _musicStarting = true;
    unawaited(_guard(_startLayers).whenComplete(() => _musicStarting = false));
  }

  Future<void> _startLayers() async {
    final soloud = SoLoud.instance;
    final handles = <SoundHandle>[];

    for (final layer in MusicLayer.values) {
      final source = _layerSources[layer.index];
      if (source == null) continue;

      final handle = await soloud.play(
        source,
        volume: _volumeOf(layer),
        looping: true,
        paused: true,
      );
      soloud.setProtectVoice(handle, true);

      _layerHandles[layer.index] = handle;
      handles.add(handle);
    }

    if (handles.isEmpty) return;

    final group = soloud.createVoiceGroup();
    soloud.addVoicesToGroup(group, handles);
    soloud.setPause(group, false);
    _musicGroup = group;
  }

  @override
  Future<void> loadMusic(MusicBank music, {required String tag}) async {
    if (!_ready || tag == _musicTag) return;

    await _guard(() async {
      final soloud = SoLoud.instance;

      final group = _musicGroup;
      _musicGroup = null;
      if (group != null) {
        soloud.setPause(group, true);
        soloud.destroyVoiceGroup(group);
      }

      for (final layer in MusicLayer.values) {
        final handle = _layerHandles[layer.index];
        if (handle != null) soloud.stop(handle);
        _layerHandles[layer.index] = null;

        final source = _layerSources[layer.index];
        if (source != null) await soloud.disposeSource(source);
        _layerSources[layer.index] = null;
      }

      _music = music;
      _musicTag = tag;
      _intensity = 0;

      await _uploadMusic();
      await _startLayers();
    });
  }

  @override
  void setMusicIntensity(int intensity) {
    final clamped = intensity < 0
        ? 0
        : (intensity > _maxIntensity ? _maxIntensity : intensity);
    if (clamped == _intensity) return;
    _intensity = clamped;
    if (!_ready) return;

    final soloud = SoLoud.instance;
    for (final layer in MusicLayer.values) {
      final handle = _layerHandles[layer.index];
      if (handle == null) continue;
      soloud.fadeVolume(handle, _volumeOf(layer), _layerFade);
    }
  }

  @override
  void setMusicPaused(bool paused) {
    final group = _musicGroup;
    if (group == null) return;
    unawaited(_guard(() async => SoLoud.instance.setPause(group, paused)));
  }

  @override
  Future<void> dispose() async {
    _ready = false;
    await _guard(() async {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) return;

      final group = _musicGroup;
      _musicGroup = null;
      if (group != null) {
        soloud.setPause(group, true);
        soloud.destroyVoiceGroup(group);
      }

      await soloud.disposeAllSources();
      soloud.deinit();
    });
  }

  static final int _maxIntensity = MusicLayer.values
      .map((layer) => layer.joinsAtIntensity)
      .reduce((a, b) => a > b ? a : b);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      debugPrint('neon_dash: audio call failed — $error');
    }
  }
}
