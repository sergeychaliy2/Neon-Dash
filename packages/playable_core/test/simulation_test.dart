import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';
import 'package:playable_core/src/application/simulation.dart';
import 'package:playable_core/src/application/world.dart';
import 'package:test/test.dart';

const double _phoneAspect = 0.45;
const double _step = 1.0 / 120.0;

void main() {
  group('Game timing', () {
    test('one step of wall time runs exactly one simulation step', () {
      final game = Game()
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun()
        ..advance(_step);

      expect(game.world.elapsed, closeTo(_step, 1e-12));
    });

    test('wall time shorter than a step accumulates instead of being lost', () {
      final game = Game()
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun();

      const third = _step / 3.0;
      game..advance(third)..advance(third);
      expect(game.world.elapsed, 0.0, reason: 'not yet a whole step');

      game..advance(third)..advance(third);
      expect(game.world.elapsed, closeTo(_step, 1e-9));
    });

    test('a long stall is discarded rather than queued', () {
      final game = Game()
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun()
        ..advance(30.0);

      final maxSteps = game.config.simulation.maxStepsPerFrame;
      expect(game.world.elapsed, closeTo(_step * maxSteps, 1e-9));
    });

    test('non-positive wall time does nothing', () {
      final game = Game()
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun()
        ..advance(0.0)
        ..advance(-1.0);

      expect(game.world.elapsed, 0.0);
    });
  });

  group('Game phases', () {
    test('a fresh game waits for input but already animates', () {
      final game = Game()..resizeToScreenAspect(_phoneAspect);
      expect(game.world.phase, GamePhase.ready);

      game.advance(_step * 4);

      expect(game.world.phase, GamePhase.ready);
      expect(game.world.elapsed, 0.0, reason: 'the clock starts with the run');
      expect(
        game.world.distance,
        greaterThan(0.0),
        reason: 'the world must be in motion on the very first frame',
      );
      expect(game.world.obstacleCount, 0, reason: 'nothing to dodge yet');
    });

    test('startRun begins the run once and records the cue', () {
      final game = Game()
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun();

      expect(game.world.phase, GamePhase.running);
      expect(game.world.eventCount, 1);
      expect(game.world.eventAt(0), GameEvent.runStarted);

      game.startRun();
      expect(game.world.eventCount, 1, reason: 'a second start is ignored');
    });

    test('consumeEvents clears the buffer', () {
      final game = Game()
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun();
      expect(game.world.eventCount, greaterThan(0));

      game.consumeEvents();

      expect(game.world.eventCount, 0);
    });

    test('an unattended craft eventually crashes', () {
      final game = Game(seed: 42)
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun();

      final steps = (90.0 / _step).round();
      for (var i = 0; i < steps && game.world.phase != GamePhase.over; i++) {
        game
          ..advance(_step)
          ..consumeEvents();
      }

      expect(
        game.world.phase,
        GamePhase.over,
        reason: 'gaps move, so standing still must not survive indefinitely',
      );
    });

    test('restart clears the run without clearing the pools', () {
      final game = Game(seed: 8)
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun();
      final steps = (20.0 / _step).round();
      for (var i = 0; i < steps; i++) {
        game..advance(_step)..consumeEvents();
      }

      game.restart();

      expect(game.world.phase, GamePhase.ready);
      expect(game.world.elapsed, 0.0);
      expect(game.world.score, 0.0);
      expect(game.world.distance, 0.0);
      expect(game.world.obstacleCount, 0);
      expect(game.world.orbCount, 0);
      expect(game.world.particleCount, 0);
      expect(game.world.nearMissCount, 0);
      expect(game.world.orbsCollected, 0);
    });
  });

  group('Determinism', () {
    test('same seed and same input produce an identical run', () {
      final first = _startedGame(777);
      final second = _startedGame(777);

      for (var i = 0; i < 3000; i++) {
        final target = (i % 97) * 0.45;
        first..moveTargetTo(target)..advance(_step)..consumeEvents();
        second..moveTargetTo(target)..advance(_step)..consumeEvents();
      }

      expect(second.world.score, first.world.score);
      expect(second.world.playerX, first.world.playerX);
      expect(second.world.phase, first.world.phase);
      expect(second.world.obstacleCount, first.world.obstacleCount);
      expect(second.world.nearMissCount, first.world.nearMissCount);
    });

    test('restartFromSeed replays the same layout', () {
      final game = _startedGame(5);
      final steps = (12.0 / _step).round();
      for (var i = 0; i < steps; i++) {
        game..advance(_step)..consumeEvents();
      }
      final firstScore = game.world.score;
      final firstPhase = game.world.phase;

      game
        ..restartFromSeed(5)
        ..startRun();
      for (var i = 0; i < steps; i++) {
        game..advance(_step)..consumeEvents();
      }

      expect(game.world.score, firstScore);
      expect(game.world.phase, firstPhase);
    });

    test('a different seed produces a different layout', () {
      final first = _startedGame(1);
      final second = _startedGame(2);

      final steps = (2.0 / _step).round();
      for (var i = 0; i < steps; i++) {
        first..advance(_step)..consumeEvents();
        second..advance(_step)..consumeEvents();
      }

      final firstLayout = _obstacleLayout(first.world);

      expect(firstLayout, isNotEmpty, reason: 'nothing spawned to compare');
      expect(_obstacleLayout(second.world), isNot(firstLayout));
    });
  });

  group('Input and viewport', () {
    test('the craft approaches its target instead of jumping to it', () {
      final game = _startedGame(1);
      final start = game.world.playerX;

      game
        ..moveTargetTo(game.world.fieldWidth)
        ..advance(_step);

      final moved = game.world.playerX - start;
      expect(moved, greaterThan(0.0));
      expect(
        moved,
        lessThan(game.world.fieldWidth * 0.1),
        reason: 'a distant tap must read as a move, not a teleport',
      );
    });

    test('input targets are clamped inside the field', () {
      final game = _startedSpawnFreeGame();

      game.moveTargetTo(-500.0);
      for (var i = 0; i < 600; i++) {
        game..advance(_step)..consumeEvents();
      }
      expect(
        game.world.playerX,
        greaterThanOrEqualTo(game.config.player.radius - 1e-6),
      );

      game.moveTargetTo(50000.0);
      for (var i = 0; i < 600; i++) {
        game..advance(_step)..consumeEvents();
      }
      expect(
        game.world.playerX,
        lessThanOrEqualTo(
          game.world.fieldWidth - game.config.player.radius + 1e-6,
        ),
      );
    });

    test('field width follows the screen but stays within its clamps', () {
      final game = Game();
      final viewport = game.config.viewport;

      game.resizeToScreenAspect(0.1);
      expect(
        game.world.fieldWidth,
        closeTo(viewport.worldHeight * viewport.minFieldAspect, 1e-9),
      );

      game.resizeToScreenAspect(5.0);
      expect(
        game.world.fieldWidth,
        closeTo(viewport.worldHeight * viewport.maxFieldAspect, 1e-9),
      );

      game.resizeToScreenAspect(0.6);
      expect(game.world.fieldWidth, closeTo(viewport.worldHeight * 0.6, 1e-9));
    });

    test('shrinking the field pulls the craft back inside it', () {
      final game = _startedSpawnFreeGame()..resizeToScreenAspect(1.78);
      game.moveTargetTo(game.world.fieldWidth);
      for (var i = 0; i < 2000; i++) {
        game..advance(_step)..consumeEvents();
      }
      final wideX = game.world.playerX;

      game.resizeToScreenAspect(0.45);

      expect(game.world.playerX, lessThan(wideX));
      expect(
        game.world.playerX,
        lessThanOrEqualTo(
          game.world.fieldWidth - game.config.player.radius + 1e-6,
        ),
      );
    });
  });

  group('Scoring', () {
    test('a close pass awards exactly one near-miss bonus', () {
      final config = _spawnFreeConfig();
      final world = _runningWorld(config);
      final simulation = Simulation(
        config: config,
        random: DeterministicRandom(1),
      )..reset();

      const halfWidth = 3.0;
      const halfHeight = 2.0;
      const surfaceGap = 1.0;
      world.addObstacle(
        x: world.playerX + config.player.radius + halfWidth + surfaceGap,
        y: world.playerY - 20.0,
        halfWidth: halfWidth,
        halfHeight: halfHeight,
        shape: ObstacleShape.box,
      );

      for (var i = 0; i < 400; i++) {
        simulation.step(world);
      }

      expect(world.phase, GamePhase.running, reason: 'a near miss is not a hit');
      expect(world.nearMissCount, 1);
      expect(world.score, greaterThan(config.score.nearMiss));
    });

    test('a wide pass awards nothing', () {
      final config = _spawnFreeConfig();
      final world = _runningWorld(config);
      final simulation = Simulation(
        config: config,
        random: DeterministicRandom(1),
      )..reset();

      const halfWidth = 3.0;
      world.addObstacle(
        x: world.playerX + config.player.radius + halfWidth + 12.0,
        y: world.playerY - 20.0,
        halfWidth: halfWidth,
        halfHeight: 2.0,
        shape: ObstacleShape.box,
      );

      for (var i = 0; i < 400; i++) {
        simulation.step(world);
      }

      expect(world.phase, GamePhase.running);
      expect(world.nearMissCount, 0);
    });

    test('an obstacle on the craft ends the run', () {
      final config = _spawnFreeConfig();
      final world = _runningWorld(config);
      final simulation = Simulation(
        config: config,
        random: DeterministicRandom(1),
      )..reset();

      world.addObstacle(
        x: world.playerX,
        y: world.playerY - 10.0,
        halfWidth: 4.0,
        halfHeight: 2.0,
        shape: ObstacleShape.box,
      );

      for (var i = 0; i < 400 && world.phase == GamePhase.running; i++) {
        simulation.step(world);
      }

      expect(world.phase, GamePhase.over);
      expect(
        world.particleCount,
        greaterThan(0),
        reason: 'the impact must throw debris',
      );
    });

    test('an orb on the craft is collected and scored', () {
      final config = _spawnFreeConfig();
      final world = _runningWorld(config);
      final simulation = Simulation(
        config: config,
        random: DeterministicRandom(1),
      )..reset();

      world.addOrb(x: world.playerX, y: world.playerY - 10.0);

      for (var i = 0; i < 400 && world.orbsCollected == 0; i++) {
        simulation.step(world);
      }

      expect(world.orbsCollected, 1);
      expect(world.orbCount, 0);
      expect(world.score, greaterThanOrEqualTo(config.score.orb));
    });
  });

  group('Pool discipline', () {
    test('pools never exceed capacity across repeated runs', () {
      final game = Game(seed: 31)..resizeToScreenAspect(_phoneAspect);
      final pools = game.config.pools;
      final steps = (240.0 / _step).round();

      game.startRun();
      for (var i = 0; i < steps; i++) {
        game
          ..moveTargetTo((i % 211) * 0.21)
          ..advance(_step)
          ..consumeEvents();

        expect(game.world.obstacleCount, lessThanOrEqualTo(pools.maxObstacles));
        expect(game.world.orbCount, lessThanOrEqualTo(pools.maxOrbs));
        expect(game.world.particleCount, lessThanOrEqualTo(pools.maxParticles));

        if (game.world.phase == GamePhase.over) {
          game
            ..restart()
            ..startRun();
        }
      }
    });

    test('the trail ring never exceeds its capacity', () {
      final game = _startedGame(12);
      final steps = (40.0 / _step).round();

      for (var i = 0; i < steps; i++) {
        game..advance(_step)..consumeEvents();
        expect(game.world.trailCount, lessThanOrEqualTo(game.world.trailCapacity));
        expect(game.world.trailHead, lessThan(game.world.trailCapacity));
      }

      expect(
        game.world.trailCount,
        game.world.trailCapacity,
        reason: 'the trail should be full well within 40 seconds',
      );
    });
  });

  group('Obstacle shapes', () {
    test('a spike is judged as a triangle, not as the box around it', () {
      final config = _frozenConfig();
      final world = _runningWorld(config);
      final simulation = _frozenSimulation(config);

      const halfHeight = 4.0;
      world.addObstacle(
        x: world.playerX + 4.5,
        y: world.playerY - halfHeight,
        halfWidth: 6.0,
        halfHeight: halfHeight,
        shape: ObstacleShape.spike,
      );

      simulation.step(world);

      expect(world.phase, GamePhase.running);
    });

    test('a spike on the craft still ends the run', () {
      final config = _frozenConfig();
      final world = _runningWorld(config);
      final simulation = _frozenSimulation(config);

      const halfHeight = 4.0;
      world.addObstacle(
        x: world.playerX,
        y: world.playerY - halfHeight,
        halfWidth: 6.0,
        halfHeight: halfHeight,
        shape: ObstacleShape.spike,
      );

      simulation.step(world);

      expect(world.phase, GamePhase.over);
    });

    test('a mine is judged from its rim, not its centre', () {
      final config = _frozenConfig();
      final radius = config.wave.mineRadius;

      final clear = _runningWorld(config);
      clear.addObstacle(
        x: clear.playerX + radius + clear.playerRadius + 0.5,
        y: clear.playerY,
        halfWidth: radius,
        halfHeight: radius,
        shape: ObstacleShape.mine,
      );
      _frozenSimulation(config).step(clear);
      expect(clear.phase, GamePhase.running, reason: 'half a unit of daylight');

      final touching = _runningWorld(config);
      touching.addObstacle(
        x: touching.playerX + radius + touching.playerRadius - 0.3,
        y: touching.playerY,
        halfWidth: radius,
        halfHeight: radius,
        shape: ObstacleShape.mine,
      );
      _frozenSimulation(config).step(touching);
      expect(touching.phase, GamePhase.over, reason: 'hulls overlap');
    });

    test('a drifting obstacle stays inside its reserved lane', () {
      final config = _frozenConfig();
      final world = _runningWorld(config);
      final simulation = _frozenSimulation(config);

      const amplitude = 3.0;
      final home = world.fieldWidth * 0.5;
      world.addObstacle(
        x: home,
        y: 10.0,
        halfWidth: 2.0,
        halfHeight: 2.0,
        shape: ObstacleShape.box,
        driftAmplitude: amplitude,
        driftRate: 0.7,
      );

      for (var i = 0; i < 20000; i++) {
        simulation.step(world);
        if (world.obstacleCount == 0) break;
        expect(
          (world.obstacleX[0] - home).abs(),
          lessThanOrEqualTo(amplitude + 1e-4),
          reason: 'the swing escaped its lane on step $i',
        );
      }
      expect(world.obstacleCount, 1, reason: 'nothing should have scrolled');
    });
  });
}

Simulation _frozenSimulation(GameConfig config) =>
    Simulation(config: config, random: DeterministicRandom(1))..reset();

GameConfig _frozenConfig() => GameConfig(
      viewport: GameConfig.neonDash.viewport,
      player: GameConfig.neonDash.player,
      difficulty: const DifficultyConfig(
        startScrollSpeed: 0.0,
        maxScrollSpeed: 0.0,
        speedRampSeconds: 1.0,
        startSpawnInterval: 10000.0,
        minSpawnInterval: 10000.0,
        spawnRampSeconds: 1.0,
        startGapFraction: 0.5,
        minGapFraction: 0.5,
        gapRampSeconds: 1.0,
      ),
      score: GameConfig.neonDash.score,
      pools: GameConfig.neonDash.pools,
      simulation: GameConfig.neonDash.simulation,
      wave: GameConfig.neonDash.wave,
      route: GameConfig.neonDash.route,
      bonus: GameConfig.neonDash.bonus,
      portal: GameConfig.neonDash.portal,
      orbRadius: GameConfig.neonDash.orbRadius,
      orbChance: 0.0,
      particleLifetime: GameConfig.neonDash.particleLifetime,
      particleSpeed: GameConfig.neonDash.particleSpeed,
      trailCapacity: GameConfig.neonDash.trailCapacity,
      trailSampleInterval: GameConfig.neonDash.trailSampleInterval,
    );

List<double> _obstacleLayout(WorldView world) => <double>[
      for (var i = 0; i < world.obstacleCount; i++) world.obstacleX[i],
    ]..sort();

Game _startedGame(int seed) => Game(seed: seed)
  ..resizeToScreenAspect(_phoneAspect)
  ..startRun()
  ..consumeEvents();

Game _startedSpawnFreeGame() => Game(config: _spawnFreeConfig(), seed: 1)
  ..resizeToScreenAspect(_phoneAspect)
  ..startRun()
  ..consumeEvents();

World _runningWorld(GameConfig config) {
  final world = World(config)
    ..setFieldWidth(config.viewport.widthForScreenAspect(_phoneAspect))
    ..resetRun();
  world.phase = GamePhase.running;
  world.playerTargetX = world.playerX;
  return world;
}

GameConfig _spawnFreeConfig() {
  const unreachableInterval = 10000.0;
  const holdSpeed = 40.0;

  return GameConfig(
    viewport: GameConfig.neonDash.viewport,
    player: GameConfig.neonDash.player,
    difficulty: const DifficultyConfig(
      startScrollSpeed: holdSpeed,
      maxScrollSpeed: holdSpeed,
      speedRampSeconds: 1.0,
      startSpawnInterval: unreachableInterval,
      minSpawnInterval: unreachableInterval,
      spawnRampSeconds: 1.0,
      startGapFraction: 0.5,
      minGapFraction: 0.5,
      gapRampSeconds: 1.0,
    ),
    score: GameConfig.neonDash.score,
    pools: GameConfig.neonDash.pools,
    simulation: GameConfig.neonDash.simulation,
    wave: GameConfig.neonDash.wave,
    route: GameConfig.neonDash.route,
    bonus: GameConfig.neonDash.bonus,
    portal: GameConfig.neonDash.portal,
    orbRadius: GameConfig.neonDash.orbRadius,
    orbChance: 0.0,
    particleLifetime: GameConfig.neonDash.particleLifetime,
    particleSpeed: GameConfig.neonDash.particleSpeed,
    trailCapacity: GameConfig.neonDash.trailCapacity,
    trailSampleInterval: GameConfig.neonDash.trailSampleInterval,
  );
}
