import 'package:playable_core/playable_core.dart';
import 'package:playable_core/src/application/world.dart';
import 'package:test/test.dart';

const double _phoneAspect = 0.45;
const double _step = 1.0 / 120.0;

void main() {
  group('Continuing a lost run', () {
    test('a crash before the first checkpoint cannot be continued', () {
      final game = _crashedEarly();

      expect(game.canContinue, isFalse);
      expect(game.continueRun(), isFalse);
      expect(game.world.phase, GamePhase.over);
    });

    test('a crash past a checkpoint resumes there', () {
      final game = _crashedAfterCheckpoint();
      final banked = game.world.checkpointsPassed;
      expect(banked, greaterThan(0));

      expect(game.canContinue, isTrue);
      expect(game.continueRun(), isTrue);

      expect(game.world.phase, GamePhase.running);
      expect(
        game.world.routeDistance,
        closeTo(game.world.route.checkpointDistance[banked - 1], 1e-3),
      );
      expect(game.world.checkpointsPassed, banked,
          reason: 'a checkpoint already banked is not re-awarded');
    });

    test('everything earned survives the resume', () {
      final game = _crashedAfterCheckpoint();
      final world = game.world as World;
      world.storeBonus(BonusKind.magnet);

      final score = world.score;
      final orbs = world.orbsCollected;
      final nearMisses = world.nearMissCount;

      expect(game.continueRun(), isTrue);

      expect(world.score, score);
      expect(world.orbsCollected, orbs);
      expect(world.nearMissCount, nearMisses);
      expect(world.slotAt(0), BonusKind.magnet);
    });

    test('the crash stays on the record', () {
      final game = _crashedAfterCheckpoint();
      expect(game.world.hitsTaken, greaterThan(0));

      final hits = game.world.hitsTaken;
      expect(game.continueRun(), isTrue);

      expect(game.world.hitsTaken, hits);
    });

    test('the field is cleared, so the craft does not resume inside a wall',
        () {
      final game = _crashedAfterCheckpoint();

      expect(game.continueRun(), isTrue);

      expect(game.world.obstacleCount, 0);
      expect(game.world.isImmune, isTrue);
      expect(game.world.playerX, closeTo(game.world.fieldWidth * 0.5, 1e-6));
    });

    test('surviving the first frame back is not a coin flip', () {
      final game = _crashedAfterCheckpoint()..continueRun();

      for (var i = 0; i < 120; i++) {
        game
          ..advance(_step)
          ..consumeEvents();
      }

      expect(game.world.phase, GamePhase.running);
    });

    test('each continue is counted and costs more than the last', () {
      final game = _crashedAfterCheckpoint();
      expect(game.world.continuesUsed, 0);

      expect(game.continueRun(), isTrue);
      expect(game.world.continuesUsed, 1);

      expect(
        RunSummary.priceOfContinue(1),
        greaterThan(RunSummary.priceOfContinue(0)),
      );
      expect(
        RunSummary.priceOfContinue(2),
        greaterThan(RunSummary.priceOfContinue(1)),
      );
    });

    test('the price stops doubling rather than overflowing', () {
      final high = RunSummary.priceOfContinue(400);

      expect(high, greaterThan(0));
      expect(high, RunSummary.priceOfContinue(500));
    });

    test('a restart clears the continue count', () {
      final game = _crashedAfterCheckpoint()..continueRun();
      expect(game.world.continuesUsed, 1);

      game.restart();

      expect(game.world.continuesUsed, 0);
    });

    test('a finished run cannot be continued', () {
      final game = _finished();
      expect(game.world.phase, GamePhase.finished);

      expect(game.canContinue, isFalse);
      expect(game.continueRun(), isFalse);
    });
  });

  group('Reading a run', () {
    test('a lost run earns no stars however well it went', () {
      final game = _crashedAfterCheckpoint();

      final summary = RunSummary.of(game.world, game.level);

      expect(summary.finished, isFalse);
      expect(summary.stars, 0);
      expect(summary.progress, lessThan(1.0));
    });

    test('a finished run earns at least one star', () {
      final game = _finished();

      final summary = RunSummary.of(game.world, game.level);

      expect(summary.finished, isTrue);
      expect(summary.stars, greaterThanOrEqualTo(1));
      expect(summary.progress, closeTo(1.0, 1e-3));
      expect(summary.progressPercent, 100);
    });

    test('the clean-run star needs an untouched run', () {
      const rules = StarRules(orbTarget: 10);

      expect(rules.evaluate(finished: true, orbs: 0, hits: 0), 2);
      expect(rules.evaluate(finished: true, orbs: 0, hits: 1), 1);
      expect(rules.evaluate(finished: true, orbs: 10, hits: 0), 3);
      expect(rules.evaluate(finished: false, orbs: 10, hits: 0), 0);
    });

    test('a lost run still pays for the ground it covered', () {
      final game = _crashedAfterCheckpoint();

      final summary = RunSummary.of(game.world, game.level);

      expect(summary.shards, greaterThan(0));
    });

    test('a summary does not change when the run behind it restarts', () {
      final game = _finished();
      final summary = RunSummary.of(game.world, game.level);
      final score = summary.score;

      game
        ..restart()
        ..startRun();

      expect(summary.score, score);
      expect(game.world.score, 0.0);
    });
  });
}

Game _openGame() => Game(config: _openConfig(), seed: 7)
  ..resizeToScreenAspect(_phoneAspect)
  ..startRun()
  ..consumeEvents();

GameConfig _openConfig() => GameConfig(
      viewport: GameConfig.neonDash.viewport,
      player: GameConfig.neonDash.player,
      difficulty: const DifficultyConfig(
        startScrollSpeed: 60.0,
        maxScrollSpeed: 60.0,
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

void _runUntil(Game game, bool Function(WorldView world) test, String what) {
  for (var i = 0; i < 200000; i++) {
    if (test(game.world)) return;
    game
      ..advance(_step)
      ..consumeEvents();
  }
  fail('never reached $what');
}

void _crashInto(Game game) {
  final world = game.world as World;
  world.addObstacle(
    x: world.playerX,
    y: world.playerY,
    halfWidth: 6.0,
    halfHeight: 3.0,
    shape: ObstacleShape.box,
  );

  _runUntil(game, (w) => w.phase == GamePhase.over, 'a crash');
}

Game _crashedEarly() {
  final game = _openGame();
  _crashInto(game);

  expect(game.world.checkpointsPassed, 0, reason: 'fixture crashed too late');
  return game;
}

Game _crashedAfterCheckpoint() {
  final game = _openGame();
  _runUntil(game, (w) => w.checkpointsPassed > 0, 'the first checkpoint');
  _crashInto(game);
  return game;
}

Game _finished() {
  final game = _openGame();
  _runUntil(game, (w) => w.phase == GamePhase.finished, 'the finish line');
  return game;
}
