library;

import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';
import 'package:playable_core/src/application/spawner.dart';
import 'package:playable_core/src/application/world.dart';
import 'package:test/test.dart';

const double _step = 1.0 / 120.0;
const double _phoneAspect = 0.45;
const int _seeds = 4;

void main() {
  test('the real game never crowds two barriers together', () {
    for (final level in LevelCatalogue.levels) {
      final floor = Game(level: level).config.wave.minRowSeconds;
      final seen = _fly(level);

      // ignore: avoid_print
      print('${level.name.padRight(14)} gaps=${seen.gaps} '
          'mean=${(seen.mean * 1000).toStringAsFixed(0)}ms '
          'worst=${(seen.worst * 1000).toStringAsFixed(0)}ms '
          'at ${seen.worstAt.toStringAsFixed(1)}s');

      expect(
        seen.gaps,
        greaterThan(20),
        reason: '${level.name}: nothing was measured',
      );
      expect(
        seen.worst,
        greaterThanOrEqualTo(floor - 0.02),
        reason: '${level.name} gives the player only '
            '${(seen.worst * 1000).toStringAsFixed(0)}ms of clear way at '
            '${seen.worstAt.toStringAsFixed(1)}s, against a floor of '
            '${(floor * 1000).toStringAsFixed(0)}ms',
      );
    }
  });

  group('The finish arrives in the clear', () {
    for (final level in LevelCatalogue.levels) {
      test(level.name, () {
        final config = Game(level: level).config;
        final runIn = config.route.finishRunIn;
        final world = _fixture(config);

        final spawner = Spawner(
          config: config,
          random: DeterministicRandom(level.index + 1),
        )..reset();

        world.routeDistance = world.route.length - runIn + 0.5;
        expect(
          world.routeRemaining,
          lessThanOrEqualTo(runIn),
          reason: 'the fixture is not actually inside the run-in',
        );

        _run(spawner, world, seconds: 6.0);

        expect(
          world.obstacleCount,
          0,
          reason: '${level.name} laid ${world.obstacleCount} obstacles inside '
              'the ${runIn.toStringAsFixed(0)}-unit run-in, which is where '
              'the finish line has to be seen',
        );
      });
    }

    test('and the stretch before it is still busy', () {
      final config = Game(level: LevelCatalogue.byIndex(0)).config;
      final world = _fixture(config);
      final spawner = Spawner(
        config: config,
        random: DeterministicRandom(1),
      )..reset();

      world.routeDistance =
          world.route.length - config.route.finishRunIn - 150.0;

      _run(spawner, world, seconds: 6.0);

      expect(world.obstacleCount, greaterThan(0));
    });
  });
}

World _fixture(GameConfig config) {
  final world = World(config)
    ..setFieldWidth(config.viewport.widthForScreenAspect(_phoneAspect))
    ..resetRun();
  world.phase = GamePhase.running;
  return world;
}

void _run(Spawner spawner, World world, {required double seconds}) {
  final steps = (seconds / _step).round();
  for (var i = 0; i < steps; i++) {
    world.elapsed += _step;
    spawner.update(world, _step);
  }
}

({int gaps, double mean, double worst, double worstAt}) _fly(
  LevelDefinition level,
) {
  var gaps = 0;
  var total = 0.0;
  var worst = double.infinity;
  var worstAt = 0.0;

  for (var seed = 1; seed <= _seeds; seed++) {
    final game = Game(level: level)
      ..resizeToScreenAspect(_phoneAspect)
      ..restartFromSeed(seed)
      ..startRun();

    var elapsed = 0.0;
    var blocked = false;
    var clearedAt = -1.0;

    final steps = (level.routeSeconds / _step).round();
    for (var i = 0; i < steps; i++) {
      _steer(game);
      game.advance(_step);
      elapsed += _step;

      final world = game.world;
      if (world.phase != GamePhase.running) {
        if (!game.continueRun()) {
          game
            ..restartFromSeed(seed + 1000 * i)
            ..startRun();
        }
        blocked = false;
        clearedAt = -1.0;
        continue;
      }

      var covering = false;
      for (var j = 0; j < world.obstacleCount; j++) {
        if ((world.obstacleY[j] - world.playerY).abs() <=
            world.obstacleHalfHeight[j]) {
          covering = true;
          break;
        }
      }

      if (covering && !blocked) {
        if (clearedAt >= 0.0) {
          final clear = elapsed - clearedAt;
          gaps++;
          total += clear;
          if (clear < worst) {
            worst = clear;
            worstAt = elapsed;
          }
        }
        blocked = true;
      } else if (!covering && blocked) {
        clearedAt = elapsed;
        blocked = false;
      }
    }
  }

  return (
    gaps: gaps,
    mean: gaps == 0 ? 0.0 : total / gaps,
    worst: worst.isFinite ? worst : 0.0,
    worstAt: worstAt,
  );
}

void _steer(Game game) {
  final world = game.world;
  final ahead = world.playerY;

  var nearest = double.infinity;
  for (var i = 0; i < world.obstacleCount; i++) {
    final distance = ahead - world.obstacleY[i];
    if (distance < 0.0) continue;
    if (distance < nearest) nearest = distance;
  }
  if (!nearest.isFinite) return;

  final depth = ahead - nearest;
  final blocked = <(double, double)>[];
  for (var i = 0; i < world.obstacleCount; i++) {
    if ((world.obstacleY[i] - depth).abs() > world.obstacleHalfHeight[i] + 2.0) {
      continue;
    }
    final reach = world.obstacleHalfWidth[i];
    blocked.add((world.obstacleX[i] - reach, world.obstacleX[i] + reach));
  }
  blocked.sort((a, b) => a.$1.compareTo(b.$1));

  var cursor = 0.0;
  var widest = 0.0;
  var centre = world.fieldWidth * 0.5;
  for (final (from, to) in blocked) {
    if (from - cursor > widest) {
      widest = from - cursor;
      centre = (cursor + from) * 0.5;
    }
    if (to > cursor) cursor = to;
  }
  if (world.fieldWidth - cursor > widest) {
    centre = (cursor + world.fieldWidth) * 0.5;
  }

  game.moveTargetTo(centre);
}
