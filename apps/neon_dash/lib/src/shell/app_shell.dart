library;

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';

import '../../main.dart' show goFullScreen;
import '../audio/cue_player.dart';
import '../storage/profile_store.dart';
import 'haptics.dart';
import 'home_screen.dart';
import '../ui/neon_widgets.dart';
import 'game_surface.dart';
import 'loading_screen.dart';
import 'menu_screen.dart';

enum _Stage {
  booting,

  home,

  menu,

  entering,

  playing,
}

class AppShell extends StatefulWidget {
  const AppShell({this.store, super.key});

  final ProfileStore? store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static const double _progressStarted = 0.08;
  static const double _progressSynthesised = 0.62;
  static const double _progressUploaded = 1.0;

  static const Duration _minimumLoad = Duration(milliseconds: 620);

  late final ProfileStore _store = widget.store ?? ProfileStore();

  Progression _profile = Progression();
  Settings _settings = Settings();
  CuePlayer _audio = const SilentCuePlayer();

  final Haptics _haptics = Haptics(enabled: true);

  _Stage _stage = _Stage.booting;
  double _progress = 0.0;
  String _caption = 'WAKING THE SYNTHESISER';

  LevelDefinition? _level;
  RunMode _mode = RunMode.fixed;

  int? _layoutSeed;

  int _menuTab = 0;

  bool _loading = false;

  static const bool _autopilot = bool.fromEnvironment('neon_dash.autopilot');

  static const int _startLevel = int.fromEnvironment('neon_dash.level');

  static const bool _unlocked = bool.fromEnvironment('neon_dash.unlocked');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_boot());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(goFullScreen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_audio.dispose());
    unawaited(_store.flush());
    super.dispose();
  }

  Future<void> _boot() async {
    final started = DateTime.now();

    _report(_progressStarted, 'READING YOUR RECORD');
    final profile = await _store.load();
    final settings = await _store.loadSettings();

    _report(_progressStarted, 'SYNTHESISING THE SOUNDTRACK');
    final rendered = await Isolate.run(renderBootAudio);

    _report(_progressSynthesised, 'STARTING THE ENGINE');
    final player = await createCuePlayer(
      cues: SoundBank.fromWavBytes(rendered.cues),
      music: MusicBank.fromWavBytes(rendered.music),
    );

    if (!mounted) {
      await player.dispose();
      return;
    }

    _report(_progressUploaded, 'READY');
    await _holdFor(started);
    if (!mounted) {
      await player.dispose();
      return;
    }

    _settings = settings;
    _audio = player
      ..setMusicVolume(settings.musicVolume)
      ..setEffectsVolume(settings.effectsVolume)
      ..startMusic();
    _haptics.enabled = settings.vibration;

    setState(() {
      _profile = _unlocked ? _everythingOpen() : profile;
      _stage = _Stage.home;
    });

    if (_autopilot) {
      await _enterLevel(LevelCatalogue.byIndex(_startLevel), RunMode.fixed);
    }
  }

  Future<void> _enterLevel(LevelDefinition level, RunMode mode) async {
    if (_loading) return;
    _loading = true;

    final started = DateTime.now();
    setState(() {
      _level = level;
      _mode = mode;
      _layoutSeed = mode.isRandomised
          ? DateTime.now().microsecondsSinceEpoch & 0x3FFFFFFF
          : null;
      _stage = _Stage.entering;
      _progress = _progressStarted;
      _caption = 'SCORING ${level.name}';
    });

    final bytes = await renderMusicVoice(level.music);
    if (!mounted) return;

    _report(_progressSynthesised, 'LOADING THE MIX');
    await _audio.loadMusic(
      MusicBank.fromWavBytes(bytes),
      tag: 'level_${level.index}',
    );
    if (!mounted) return;

    _report(_progressUploaded, 'GO');
    await _holdFor(started);
    if (!mounted) return;

    _loading = false;
    setState(() => _stage = _Stage.playing);
  }

  Future<void> _holdFor(DateTime started) async {
    final spent = DateTime.now().difference(started);
    final left = _minimumLoad - spent;
    if (left > Duration.zero) await Future<void>.delayed(left);
  }

  void _report(double progress, String caption) {
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _caption = caption;
    });
  }

  void _settleRun(RunSummary summary) {
    _profile
      ..record(summary.levelIndex, summary.stars)
      ..recordScore(summary.levelIndex, summary.score, mode: summary.mode)
      ..addShards(summary.shards)
      ..countRun(
        orbs: summary.orbs,
        nearMisses: summary.nearMisses,
        bonusesSpent: summary.bonusesSpent,
        continuesBought: summary.continuesUsed,
        stars: summary.stars,
        finished: summary.finished,
        shifting: summary.mode.isRandomised,
      );

    _saveProfile();
  }

  void _saveSettings() {
    _audio
      ..setMusicVolume(_settings.musicVolume)
      ..setEffectsVolume(_settings.effectsVolume);
    _haptics.enabled = _settings.vibration;

    unawaited(_store.saveSettings(_settings));
    if (mounted) setState(() {});
  }

  void _saveProfile() {
    if (!_unlocked) unawaited(_store.save(_profile));
    if (mounted) setState(() {});
  }

  void _exitToMenu() {
    _audio.setMusicIntensity(0);
    setState(() {
      _stage = _Stage.menu;
      _level = null;
    });
  }

  @override
  Widget build(BuildContext context) => ScreenSwitch(child: _buildStage());

  Widget _buildStage() => switch (_stage) {
        _Stage.booting => LoadingScreen(
            key: const ValueKey<String>('boot'),
            title: 'NEON DASH',
            caption: _caption,
            progress: _progress,
          ),
        _Stage.entering => LoadingScreen(
            key: const ValueKey<String>('entering'),
            title: _level?.name ?? 'NEON DASH',
            caption: _caption,
            progress: _progress,
            theme: _level?.theme,
          ),
        _Stage.home => HomeScreen(
            key: const ValueKey<String>('home'),
            progression: _profile,
            onFly: (level) =>
                unawaited(_enterLevel(level, RunMode.fixed)),
            onOpenMenu: () => setState(() => _stage = _Stage.menu),
          ),
        _Stage.menu => MenuScreen(
            key: const ValueKey<String>('menu'),
            progression: _profile,
            initialTab: _menuTab,
            settings: _settings,
            onSettingsChanged: _saveSettings,
            onTabChanged: (tab) => _menuTab = tab,
            onPlay: (level, mode) => unawaited(_enterLevel(level, mode)),
            onProfileChanged: _saveProfile,
          ),
        _Stage.playing => GameSurface(
            key: ValueKey<String>('${_level!.index}/${_mode.name}'),
            level: _level!,
            mode: _mode,
            layoutSeed: _layoutSeed,
            audio: _audio,
            haptics: _haptics,
            progression: _profile,
            onProfileChanged: _saveProfile,
            onRunSettled: _settleRun,
            onExitToMenu: _exitToMenu,
            onPlayLevel: (level, mode) =>
                unawaited(_enterLevel(level, mode)),
          ),
      };
}

Progression _everythingOpen() {
  final profile = Progression(shards: 50000);

  for (final level in LevelCatalogue.levels) {
    profile
      ..record(level.index, StarRules.maxPerLevel)
      ..recordScore(level.index, 1000 + level.index * 250);
  }
  for (final skin in CraftSkin.values) {
    profile.buySkin(skin);
  }
  for (final upgrade in Upgrade.values) {
    for (var rank = 0; rank < upgrade.maxRank; rank++) {
      profile.buy(upgrade);
    }
  }

  return profile..selectSkin(CraftSkin.standard);
}

Future<List<Uint8List>> renderMusicVoice(MusicVoice voice) =>
    Isolate.run(() => MusicBank.renderWavBytes(voice: voice));

({List<Uint8List> cues, List<Uint8List> music}) renderBootAudio() => (
      cues: SoundBank.renderWavBytes(),
      music: MusicBank.renderWavBytes(),
    );
