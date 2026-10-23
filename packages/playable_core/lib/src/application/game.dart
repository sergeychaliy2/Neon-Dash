import '../config/game_config.dart';
import '../domain/craft_skin.dart';
import 'package:playable_kit/playable_kit.dart';
import '../domain/game_event.dart';
import '../domain/game_phase.dart';
import '../domain/level.dart';
import '../domain/level_catalogue.dart';
import '../domain/run_mode.dart';
import '../domain/upgrade.dart';
import 'simulation.dart';
import 'world.dart';

class Game {
  Game({
    GameConfig? config,
    LevelDefinition? level,
    UpgradeLoadout loadout = UpgradeLoadout.none,
    this.skin = CraftSkin.standard,
    this.mode = RunMode.fixed,
    int? seed,
  })  : _overrideConfig = config,
        _explicitSeed = seed,
        // ignore: prefer_initializing_formals
        _loadout = loadout,
        _layoutRandom = DeterministicRandom(seed ?? defaultSeed),
        _effectRandom = DeterministicRandom(seed ?? defaultSeed) {
    _applyLevel(level ?? LevelCatalogue.levels.first);
  }

  static const int defaultSeed = 0x5EED1;

  static const int _seedStride = 7919;

  final RunMode mode;

  final CraftSkin skin;

  final int? _explicitSeed;

  int _seedFor(LevelDefinition level) =>
      _explicitSeed ?? defaultSeed + level.index * _seedStride;

  void _seedStreams() {
    final seed = _seedFor(_level);
    _layoutRandom.reseed(seed);
    _effectRandom.reseed(seed ^ _effectSeedMix);
  }

  static const int _effectSeedMix = 0x9E3779B9;

  final GameConfig? _overrideConfig;

  final DeterministicRandom _layoutRandom;

  final DeterministicRandom _effectRandom;

  final UpgradeLoadout _loadout;

  late LevelDefinition _level;
  late GameConfig _config;
  late FixedStepClock _clock;
  late World _world;
  late Simulation _simulation;

  LevelDefinition get level => _level;

  GameConfig get config => _config;

  UpgradeLoadout get loadout => _loadout;

  void loadLevel(LevelDefinition level) => _applyLevel(level);

  void _applyLevel(LevelDefinition level) {
    _level = level;
    _seedStreams();
    _config = _overrideConfig ?? _configForLevel(level);

    _world = World(_config)
      ..setStage(level.stageNumber)
      ..resetRun();
    _simulation = Simulation(
      config: _config,
      random: _effectRandom,
      layout: _layoutRandom,
    )..reset();
    _clock = FixedStepClock(
      stepSeconds: _config.simulation.fixedStep,
      maxStepsPerFrame: _config.simulation.maxStepsPerFrame,
    );
  }

  GameConfig _configForLevel(LevelDefinition level) {
    const base = GameConfig.neonDash;
    return GameConfig(
      viewport: base.viewport,
      player: base.player.withHull(skin),
      difficulty: level.difficulty,
      score: base.score,
      pools: base.pools,
      simulation: base.simulation,
      wave: level.wave.copyWith(beatSeconds: level.music.beatSeconds),
      route: level.route,
      bonus: base.bonus.withAvailable(level.bonuses).withLoadout(_loadout),
      portal: base.portal.withAvailable(level.portals),
      orbRadius: base.orbRadius,
      orbChance: base.orbChance,
      particleLifetime: base.particleLifetime,
      particleSpeed: base.particleSpeed,
      trailCapacity: base.trailCapacity,
      trailSampleInterval: base.trailSampleInterval,
    );
  }

  WorldView get world => _world;

  void resizeToScreenAspect(double screenAspect) {
    final width = config.viewport.widthForScreenAspect(screenAspect);
    if (width == _world.fieldWidth) return;
    _world.setFieldWidth(width);
  }

  int get stage => _world.route.stage;

  void loadStage(int stage) {
    _world
      ..setStage(stage)
      ..resetRun();
    _simulation.reset();
    _clock.reset();
  }

  void startRun() {
    if (_world.phase != GamePhase.ready) return;
    _world.phase = GamePhase.running;
    _world.pushEvent(GameEvent.runStarted);
  }

  void restart() {
    if (!mode.isRandomised) _seedStreams();
    _clock.reset();
    _world.resetRun();
    _simulation.reset();
  }

  void restartFromSeed(int seed) {
    _layoutRandom.reseed(seed);
    _effectRandom.reseed(seed ^ _effectSeedMix);
    _clock.reset();
    _world.resetRun();
    _simulation.reset();
  }

  bool continueRun() {
    if (_world.phase != GamePhase.over) return false;
    if (!_world.resumeAtCheckpoint()) return false;

    _clock.reset();
    return true;
  }

  bool get canContinue =>
      _world.phase == GamePhase.over && _world.checkpointsPassed > 0;

  bool activateSlot(int index) {
    if (_world.phase != GamePhase.running) return false;

    final kind = _world.takeFromSlot(index);
    if (kind == null) return false;

    _world.bonusesSpent++;
    _world
      ..beginBonus(kind)
      ..pushEvent(GameEvent.bonusSpent);
    return true;
  }

  void moveTargetTo(double worldX) {
    final radius = config.player.radius;
    final rightLimit = _world.fieldWidth - radius;
    if (worldX < radius) {
      _world.playerTargetX = radius;
    } else if (worldX > rightLimit) {
      _world.playerTargetX = rightLimit;
    } else {
      _world.playerTargetX = worldX;
    }
  }

  void dragTargetBy(double deltaWorldX) {
    moveTargetTo(_world.playerTargetX + deltaWorldX);
  }

  void advance(double realSeconds) {
    final steps = _clock.consume(realSeconds);
    for (var i = 0; i < steps; i++) {
      _simulation.step(_world);
    }
  }

  void consumeEvents() => _world.clearEvents();
}
