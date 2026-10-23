import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';
import 'package:playable_core/src/application/simulation.dart';
import 'package:playable_core/src/application/spawner.dart';
import 'package:playable_core/src/application/world.dart';
import 'package:test/test.dart';

const double _phoneAspect = 0.45;
const double _step = 1.0 / 120.0;

void main() {
  group('Slots', () {
    test('a fresh run carries nothing', () {
      final world = _world();

      expect(world.slotCount, GameConfig.neonDash.bonus.slotCount);
      for (var i = 0; i < world.slotCount; i++) {
        expect(world.slotAt(i), isNull);
      }
      expect(world.shieldCharges, 0);
    });

    test('power-ups fill the first free slot in order', () {
      final world = _world()
        ..storeBonus(BonusKind.chrono)
        ..storeBonus(BonusKind.shield);

      expect(world.slotAt(0), BonusKind.chrono);
      expect(world.slotAt(1), BonusKind.shield);
      expect(world.slotAt(2), isNull);
    });

    test('a full set of slots refuses rather than overwriting', () {
      final world = _world();
      final kinds = BonusKind.values.take(world.slotCount).toList();
      for (final kind in kinds) {
        expect(world.storeBonus(kind), isTrue);
      }

      expect(world.storeBonus(BonusKind.values.last), isFalse);
      for (var i = 0; i < world.slotCount; i++) {
        expect(world.slotAt(i), kinds[i]);
      }
    });

    test('a kind already in hand is refused, free slot or not', () {
      final world = _world();
      expect(world.storeBonus(BonusKind.shield), isTrue);

      expect(world.storeBonus(BonusKind.shield), isFalse);

      expect(world.slotAt(1), isNull, reason: 'and nothing was consumed');
      expect(world.holdsBonus(BonusKind.shield), isTrue);
      expect(world.holdsBonus(BonusKind.chrono), isFalse);
    });

    test('spending one frees its kind to be picked up again', () {
      final world = _world()..storeBonus(BonusKind.chrono);
      expect(world.storeBonus(BonusKind.chrono), isFalse);

      world.takeFromSlot(0);

      expect(world.storeBonus(BonusKind.chrono), isTrue);
    });

    test('taking from a slot empties it', () {
      final world = _world()..storeBonus(BonusKind.chrono);

      expect(world.takeFromSlot(0), BonusKind.chrono);
      expect(world.slotAt(0), isNull);
      expect(world.takeFromSlot(0), isNull);
    });

    test('taking from a slot that does not exist is harmless', () {
      final world = _world();

      expect(world.takeFromSlot(-1), isNull);
      expect(world.takeFromSlot(99), isNull);
    });
  });

  group('Spending', () {
    test('activating a slot starts the bonus and empties it', () {
      final game = _startedGame();
      expect(game.world.slotAt(0), isNotNull);

      expect(game.activateSlot(0), isTrue);

      expect(game.world.slotAt(0), isNull);
      expect(game.world.isActive(BonusKind.chrono), isTrue);
      expect(game.world.remainingFor(BonusKind.chrono), BonusKind.chrono.seconds);
    });

    test('activating an empty slot does nothing', () {
      final game = _startedGame();

      expect(game.activateSlot(1), isFalse);
    });

    test('nothing can be spent outside a run', () {
      final game = _startedGame();
      final world = _rawWorld(game);
      world.phase = GamePhase.over;

      expect(game.activateSlot(0), isFalse);
      expect(game.world.slotAt(0), isNotNull);
    });

    test('a shield banks a charge rather than running a timer', () {
      final world = _world()..beginBonus(BonusKind.shield);

      expect(world.shieldCharges, 1);
      expect(world.remainingFor(BonusKind.shield), 0.0);
      expect(world.isActive(BonusKind.shield), isTrue);
    });

    test('spending the same bonus twice refreshes it rather than stacking',
        () {
      final world = _world()
        ..beginBonus(BonusKind.chrono)
        ..beginBonus(BonusKind.chrono);

      expect(
        world.remainingFor(BonusKind.chrono),
        closeTo(BonusKind.chrono.seconds, 1e-9),
      );
    });

    test('a refresh never shortens what is already running', () {
      final world = _runningWorld()..beginBonus(BonusKind.chrono);
      final simulation = _simulation();
      for (var i = 0; i < 30; i++) {
        simulation.step(world);
      }
      final partway = world.remainingFor(BonusKind.chrono);
      expect(partway, lessThan(BonusKind.chrono.seconds));

      world.beginBonus(BonusKind.chrono);

      expect(world.remainingFor(BonusKind.chrono),
          closeTo(BonusKind.chrono.seconds, 1e-9));
      expect(world.remainingFor(BonusKind.chrono), greaterThan(partway));
    });
  });

  group('Effects', () {
    test('chrono slows the world and overdrive speeds it', () {
      final world = _world();
      expect(world.worldSpeedScale, 1.0);

      world.beginBonus(BonusKind.chrono);
      expect(world.worldSpeedScale, BonusKind.chrono.worldSpeedScale);
      expect(world.worldSpeedScale, lessThan(1.0));

      world.beginBonus(BonusKind.overdrive);
      expect(
        world.worldSpeedScale,
        closeTo(
          BonusKind.chrono.worldSpeedScale *
              BonusKind.overdrive.worldSpeedScale,
          1e-9,
        ),
      );
    });

    test('overdrive doubles points and grants immunity', () {
      final world = _world()..beginBonus(BonusKind.overdrive);

      expect(world.scoreScale, BonusKind.overdrive.scoreScale);
      expect(world.isImmune, isTrue);
    });

    test('a slow-down really does slow the scroll', () {
      final slow = _runningWorld();
      final normal = _runningWorld();
      final simulation = _simulation();

      slow.beginBonus(BonusKind.chrono);
      for (var i = 0; i < 60; i++) {
        simulation.step(slow);
        simulation.step(normal);
      }

      expect(slow.routeDistance, lessThan(normal.routeDistance));
    });

    test('timers run down and then stop', () {
      final world = _runningWorld()..beginBonus(BonusKind.chrono);
      final simulation = _simulation();

      final steps = ((BonusKind.chrono.seconds + 0.5) / _step).round();
      for (var i = 0; i < steps; i++) {
        simulation.step(world);
      }

      expect(world.remainingFor(BonusKind.chrono), 0.0);
      expect(world.isActive(BonusKind.chrono), isFalse);
      expect(world.worldSpeedScale, 1.0);
    });

    test('a magnet collects an orb the craft never touches', () {
      final pulled = _runningWorld();
      final ignored = _runningWorld();
      final simulation = _simulation();

      for (final world in <World>[pulled, ignored]) {
        world.addOrb(x: world.playerX + 12.0, y: world.playerY);
      }
      pulled.beginBonus(BonusKind.magnet);

      for (var i = 0; i < 20; i++) {
        simulation.step(pulled);
        simulation.step(ignored);
      }

      expect(pulled.orbCount, 0, reason: 'pulled in and banked');
      expect(ignored.orbCount, 1, reason: 'still out there');
      expect(pulled.score, greaterThan(ignored.score));
    });

    test('a magnet reaches no further than its radius', () {
      final world = _runningWorld()..beginBonus(BonusKind.magnet);
      final reach = GameConfig.neonDash.bonus.magnetRadius;
      world.addOrb(x: world.playerX, y: world.playerY - reach * 2.0);
      final startY = world.orbY[0];

      _simulation().step(world);

      expect(world.orbY[0], greaterThan(startY));
      expect(world.orbX[0], closeTo(world.playerX, 1e-6));
    });
  });

  group('Immunity', () {
    test('the grace is far too short to carry past the next wall', () {
      final grace = GameConfig.neonDash.bonus.immunitySeconds;

      for (final level in LevelCatalogue.levels) {
        final speed = level.difficulty.maxScrollSpeed;
        final waveSeconds = Spawner.alignToBeat(
          level.difficulty.minSpawnInterval,
          level.music.beatSeconds,
        );

        expect(
          grace * speed,
          lessThan(waveSeconds * speed * 0.6),
          reason: '${level.name}: the grace reaches more than half way to '
              'the next wave',
        );
      }
    });

    test('the grace still outlasts the obstacle that caused it', () {
      final grace = GameConfig.neonDash.bonus.immunitySeconds;
      final clearance = GameConfig.neonDash.wave.boxHalfHeight +
          GameConfig.neonDash.player.radius;

      for (final level in LevelCatalogue.levels) {
        expect(
          grace * level.difficulty.maxScrollSpeed,
          greaterThan(clearance),
          reason: '${level.name}: the craft is still inside the wall',
        );
      }
    });

    test('overdrive stops being untouchable long before it runs out', () {
      final world = _runningWorld()..beginBonus(BonusKind.overdrive);
      expect(world.isImmune, isTrue, reason: 'a moment to adjust');

      final simulation = _simulation();
      final steps =
          ((BonusKind.overdrive.graceSeconds + 0.1) / _step).round();
      for (var i = 0; i < steps; i++) {
        simulation.step(world);
      }

      expect(world.isImmune, isFalse);
      expect(world.isActive(BonusKind.overdrive), isTrue,
          reason: 'but the speed and the double score carry on');
    });

    test('an overdrive that has stopped protecting can still be hit', () {
      final world = _runningWorld()..beginBonus(BonusKind.overdrive);
      final simulation = _simulation();
      for (var i = 0; i < (1.2 / _step).round(); i++) {
        simulation.step(world);
      }

      world.addObstacle(
        x: world.playerX,
        y: world.playerY,
        halfWidth: 6.0,
        halfHeight: 3.0,
        shape: ObstacleShape.box,
      );
      simulation.step(world);

      expect(world.phase, GamePhase.over);
    });

    test('immunity is one timer, not a state per power-up', () {
      final world = _world();
      expect(world.isImmune, isFalse);

      world.immunityRemaining = 0.5;
      expect(world.isImmune, isTrue);

      world.immunityRemaining = 0.0;
      expect(world.isImmune, isFalse);
    });
  });

  group('Shields and impacts', () {
    test('a shield absorbs an impact and is spent', () {
      final world = _runningWorld()..beginBonus(BonusKind.shield);
      world.addObstacle(
        x: world.playerX,
        y: world.playerY,
        halfWidth: 6.0,
        halfHeight: 3.0,
        shape: ObstacleShape.box,
      );

      _simulation().step(world);

      expect(world.phase, GamePhase.running, reason: 'survived');
      expect(world.shieldCharges, 0);
      expect(world.hitsTaken, 1);
    });

    test('one obstacle cannot eat every charge in a single pass', () {
      final world = _runningWorld()
        ..beginBonus(BonusKind.shield)
        ..beginBonus(BonusKind.shield);
      world.addObstacle(
        x: world.playerX,
        y: world.playerY,
        halfWidth: 6.0,
        halfHeight: 3.0,
        shape: ObstacleShape.box,
      );

      final simulation = _simulation();
      for (var i = 0; i < 10; i++) {
        simulation.step(world);
      }

      expect(world.shieldCharges, 1, reason: 'only one should be spent');
      expect(world.hitsTaken, 1);
    });

    test('without a shield an impact ends the run', () {
      final world = _runningWorld();
      world.addObstacle(
        x: world.playerX,
        y: world.playerY,
        halfWidth: 6.0,
        halfHeight: 3.0,
        shape: ObstacleShape.box,
      );

      _simulation().step(world);

      expect(world.phase, GamePhase.over);
      expect(world.hitsTaken, 1);
    });

    test('overdrive passes through untouched and uncounted', () {
      final world = _runningWorld()..beginBonus(BonusKind.overdrive);
      world.addObstacle(
        x: world.playerX,
        y: world.playerY,
        halfWidth: 6.0,
        halfHeight: 3.0,
        shape: ObstacleShape.box,
      );

      _simulation().step(world);

      expect(world.phase, GamePhase.running);
      expect(
        world.hitsTaken,
        0,
        reason: 'spending a slot to cross cleanly is a fair way to earn the '
            'clean-run star',
      );
    });
  });

  group('Pickups in the field', () {
    const mode = RunMode.shifting;

    Game runner(int levelIndex, int seed) =>
        Game(level: LevelCatalogue.byIndex(levelIndex), mode: mode, seed: seed)
          ..resizeToScreenAspect(_phoneAspect)
          ..startRun();

    int collectDrops(
      Game game, {
      required int wanted,
      required void Function(BonusKind kind) onDrop,
      void Function()? onRestart,
    }) {
      final world = game.world as World;
      var seen = 0;

      for (var i = 0; i < 200000 && seen < wanted; i++) {
        game.advance(_step);
        for (var p = 0; p < world.pickupCount; p++) {
          onDrop(world.pickupKindAt(p));
          seen++;
        }
        world.pickupCount = 0;
        game.consumeEvents();

        if (world.phase == GamePhase.over) {
          game
            ..restart()
            ..startRun();
          onRestart?.call();
        }
      }
      return seen;
    }

    test('a field that offers no power-ups spawns none', () {
      final game = Game(config: _config(), seed: 2)
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun();
      expect(game.config.bonus.available, isEmpty);

      for (var i = 0; i < 6000; i++) {
        game
          ..advance(_step)
          ..consumeEvents();
        expect(game.world.pickupCount, 0);
        if (game.world.phase == GamePhase.over) {
          game
            ..restart()
            ..startRun();
        }
      }
    });

    test('a level that offers power-ups eventually drops one', () {
      final seen = collectDrops(runner(0, 11), wanted: 1, onDrop: (_) {});

      expect(seen, greaterThan(0));
    });

    test('only the kinds a level offers can appear', () {
      final level = LevelCatalogue.levels.firstWhere(
        (candidate) => candidate.bonuses.length == 2,
      );
      final game =
          Game(level: level, mode: mode, seed: 7)
            ..resizeToScreenAspect(_phoneAspect)
            ..startRun();

      final seen = collectDrops(
        game,
        wanted: 20,
        onDrop: (kind) => expect(level.bonuses, contains(kind)),
      );

      expect(seen, greaterThan(0), reason: 'and something did appear');
    });

    test('the same power-up never drops twice in a row', () {
      final level = LevelCatalogue.levels.firstWhere(
        (candidate) => candidate.bonuses.length > 1,
      );
      final game =
          Game(level: level, mode: mode, seed: 21)
            ..resizeToScreenAspect(_phoneAspect)
            ..startRun();

      BonusKind? previous;
      final seen = collectDrops(
        game,
        wanted: 30,
        onDrop: (kind) {
          expect(kind, isNot(previous), reason: 'two of the same in a row');
          previous = kind;
        },
        onRestart: () => previous = null,
      );

      expect(seen, greaterThan(5), reason: 'enough drops to mean something');
    });

    test('nothing drops that the craft is already carrying', () {
      final level = LevelCatalogue.levels.firstWhere(
        (candidate) => candidate.bonuses.length > 1,
      );

      Game carrying(bool hold) {
        final game =
            Game(level: level, mode: mode, seed: 33)
              ..resizeToScreenAspect(_phoneAspect);
        if (hold) {
          for (final kind in level.bonuses) {
            (game.world as World).storeBonus(kind);
          }
        }
        return game..startRun();
      }

      final control = collectDrops(
        carrying(false),
        wanted: 5,
        onDrop: (_) {},
      );
      expect(control, greaterThan(0), reason: 'the control must see drops');

      final held = carrying(true);
      final seen = collectDrops(
        held,
        wanted: 1,
        onDrop: (_) {},
        onRestart: () {
          for (final kind in level.bonuses) {
            (held.world as World).storeBonus(kind);
          }
        },
      );

      expect(seen, 0, reason: 'every kind this level offers is in hand');
    });

    test('what the player carries does not change the obstacle layout', () {
      String layout({required bool carrying}) {
        final game = Game(level: LevelCatalogue.byIndex(3), seed: 8)
          ..resizeToScreenAspect(_phoneAspect);
        final world = game.world as World;
        if (carrying) {
          for (final kind in game.level.bonuses) {
            world.storeBonus(kind);
          }
        }
        game.startRun();

        final parts = <String>[];
        var seen = 0;
        for (var i = 0; i < 3000; i++) {
          game
            ..advance(_step)
            ..consumeEvents();
          for (var o = seen; o < world.obstacleCount; o++) {
            parts.add(world.obstacleX[o].toStringAsFixed(3));
          }
          seen = world.obstacleCount;
        }
        return parts.join(',');
      }

      expect(layout(carrying: true), layout(carrying: false));
    });
  });
}

GameConfig _config() => GameConfig(
      viewport: GameConfig.neonDash.viewport,
      player: GameConfig.neonDash.player,
      difficulty: const DifficultyConfig(
        startScrollSpeed: 40.0,
        maxScrollSpeed: 40.0,
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

World _world() => World(_config())
  ..setFieldWidth(
    GameConfig.neonDash.viewport.widthForScreenAspect(_phoneAspect),
  )
  ..resetRun();

World _runningWorld() {
  final world = _world();
  world.phase = GamePhase.running;
  world.playerTargetX = world.playerX;
  return world;
}

Simulation _simulation() =>
    Simulation(config: _config(), random: DeterministicRandom(1))..reset();

Game _startedGame() {
  final game = Game(config: _config(), seed: 3)
    ..resizeToScreenAspect(_phoneAspect)
    ..startRun()
    ..consumeEvents();
  _rawWorld(game).storeBonus(BonusKind.chrono);
  return game;
}

World _rawWorld(Game game) => game.world as World;
