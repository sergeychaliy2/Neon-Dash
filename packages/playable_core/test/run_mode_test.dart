import 'package:playable_core/playable_core.dart';
import 'package:test/test.dart';

const double _phoneAspect = 0.45;
const double _step = 1.0 / 120.0;

void main() {
  group('A fixed level is the same level twice', () {
    test('two games on the same level lay out identically', () {
      expect(_layoutOf(_game(2)), _layoutOf(_game(2)));
    });

    test('a retry meets the same waves in the same places', () {
      final game = _game(3);
      final first = _layoutOf(game);

      game.restart();

      expect(_layoutOf(game), first);
    });

    test('a retry after a crash is still the same level', () {
      final game = _game(1);
      final first = _layoutOf(game);

      game.startRun();
      for (var i = 0; i < 20000; i++) {
        if (game.world.phase == GamePhase.over) break;
        game
          ..advance(_step)
          ..consumeEvents();
      }
      expect(game.world.phase, GamePhase.over, reason: 'fixture crashed');

      game.restart();

      expect(_layoutOf(game), first);
    });

    test('two different levels are two different layouts', () {
      expect(_layoutOf(_game(2)), isNot(_layoutOf(_game(5))));
    });

    test('the layout does not depend on the order levels were loaded', () {
      final direct = _layoutOf(_game(6));

      final wandering = Game(level: LevelCatalogue.byIndex(0))
        ..resizeToScreenAspect(_phoneAspect);
      wandering
        ..startRun()
        ..advance(2.0)
        ..consumeEvents()
        ..loadLevel(LevelCatalogue.byIndex(6));

      expect(_layoutOf(wandering), direct);
    });
  });

  group('A shifting level is a different level every time', () {
    test('a retry lays out differently', () {
      final game = Game(
        level: LevelCatalogue.byIndex(3),
        mode: RunMode.shifting,
      )..resizeToScreenAspect(_phoneAspect);

      final first = _layoutOf(game);
      game.restart();

      expect(_layoutOf(game), isNot(first));
    });

    test('an explicit seed still makes it reproducible', () {
      String run(int seed) => _layoutOf(
            Game(
              level: LevelCatalogue.byIndex(3),
              mode: RunMode.shifting,
              seed: seed,
            )..resizeToScreenAspect(_phoneAspect),
          );

      expect(run(77), run(77));
      expect(run(77), isNot(run(78)));
    });

    test('it pays more than the same run would in fixed mode', () {
      expect(
        RunMode.shifting.shardScale,
        greaterThan(RunMode.fixed.shardScale),
      );
      expect(RunMode.shifting.isRandomised, isTrue);
      expect(RunMode.fixed.isRandomised, isFalse);
    });

    test('every mode says what it is, for the card that offers it', () {
      for (final mode in RunMode.values) {
        expect(mode.title, isNotEmpty, reason: mode.name);
        expect(mode.detail, isNotEmpty, reason: mode.name);
        expect(mode.shardScale, greaterThan(0.0), reason: mode.name);
      }
    });
  });

  group('What a mode is worth', () {
    test('shifting pays more shards for the same run', () {
      final fixed = _summaryWith(RunMode.fixed);
      final shifting = _summaryWith(RunMode.shifting);

      expect(shifting.shards, greaterThan(fixed.shards));
      expect(shifting.stars, fixed.stars, reason: 'stars are not scaled');
    });

    test('the two modes keep separate records', () {
      final profile = Progression()
        ..recordScore(4, 900)
        ..recordScore(4, 2000, mode: RunMode.shifting);

      expect(profile.bestScoreFor(4), 900);
      expect(profile.bestScoreFor(4, mode: RunMode.shifting), 2000);
    });

    test('a lucky shifting run cannot retire the fixed record', () {
      final profile = Progression()..recordScore(4, 5000);

      expect(
        profile.recordScore(4, 9000, mode: RunMode.shifting),
        isTrue,
      );
      expect(profile.bestScoreFor(4), 5000, reason: 'untouched');
    });

    test('the headline best covers both modes', () {
      final profile = Progression()
        ..recordScore(0, 100)
        ..recordScore(1, 7000, mode: RunMode.shifting);

      expect(profile.bestScore, 7000);
    });

    test('both records survive a round trip', () {
      final profile = Progression()
        ..recordScore(2, 1234)
        ..recordScore(2, 4321, mode: RunMode.shifting);

      final restored = Progression.fromJson(profile.toJson());

      expect(restored.bestScoreFor(2), 1234);
      expect(restored.bestScoreFor(2, mode: RunMode.shifting), 4321);
    });
  });

  group('Earning the shifting variant', () {
    test('it is locked until the level has been cleared', () {
      final profile = Progression();

      expect(profile.isShiftingUnlocked(0), isFalse);

      profile.record(0, 1);

      expect(profile.isShiftingUnlocked(0), isTrue);
    });

    test('playing a level without finishing it does not open it', () {
      final profile = Progression()
        ..countRun(orbs: 30)
        ..recordScore(0, 9999);

      expect(profile.isShiftingUnlocked(0), isFalse);
    });
  });
}

Game _game(int levelIndex) => Game(level: LevelCatalogue.byIndex(levelIndex))
  ..resizeToScreenAspect(_phoneAspect);

String _layoutOf(Game game) {
  final world = game.world;
  final parts = <String>[];
  var seen = 0;

  game.startRun();
  for (var i = 0; i < 1800; i++) {
    game.advance(_step);
    game.consumeEvents();

    if (world.obstacleCount > seen) {
      for (var o = seen; o < world.obstacleCount; o++) {
        parts.add('${world.obstacleX[o].toStringAsFixed(2)}'
            ',${world.obstacleHalfWidth[o].toStringAsFixed(2)}'
            ',${world.obstacleShapeAt(o).index}');
      }
    }
    seen = world.obstacleCount;
  }

  if (parts.isEmpty) fail('nothing spawned, so nothing was compared');
  return parts.join('|');
}

RunSummary _summaryWith(RunMode mode) => RunSummary(
      levelIndex: 1,
      mode: mode,
      finished: true,
      score: 1000,
      orbs: 12,
      nearMisses: 3,
      hits: 0,
      progress: 1.0,
      checkpointsPassed: 4,
      continuesUsed: 0,
      bonusesSpent: 2,
      stars: 3,
      shards: (37 * mode.shardScale).round(),
    );
