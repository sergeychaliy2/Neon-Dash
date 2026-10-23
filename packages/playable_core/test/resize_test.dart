import 'package:playable_core/playable_core.dart';
import 'package:test/test.dart';

const double _wideAspect = 0.70;

const double _narrowAspect = 0.45;

const double _step = 1.0 / 120.0;

const double _worldEpsilon = 1e-4;

const double _ratioEpsilon = 1e-5;

void main() {
  group('Field resize', () {
    test('a shrink leaves every live wave passable', () {
      final craftDiameter = GameConfig.neonDash.player.radius * 2.0;
      var wavesChecked = 0;

      for (var seed = 1; seed <= 30; seed++) {
        final game = Game(seed: seed)
          ..resizeToScreenAspect(_wideAspect)
          ..startRun();

        for (var i = 0; i < 300; i++) {
          game
            ..advance(_step)
            ..consumeEvents();
        }
        if (game.world.obstacleCount == 0) continue;

        game.resizeToScreenAspect(_narrowAspect);

        final world = game.world;
        for (var i = 0; i < world.obstacleCount; i++) {
          wavesChecked++;
          expect(
            _largestFreeSpanAt(world, world.obstacleY[i]),
            greaterThanOrEqualTo(craftDiameter),
            reason: 'seed $seed left no reachable gap after a shrink',
          );
        }
      }

      expect(wavesChecked, greaterThan(20), reason: 'nothing was examined');
    });

    test('every obstacle stays inside the field after a shrink', () {
      final game = Game(seed: 4)
        ..resizeToScreenAspect(_wideAspect)
        ..startRun();
      for (var i = 0; i < 400; i++) {
        game
          ..advance(_step)
          ..consumeEvents();
      }

      game.resizeToScreenAspect(_narrowAspect);

      final world = game.world;
      expect(world.obstacleCount, greaterThan(0));
      for (var i = 0; i < world.obstacleCount; i++) {
        expect(
          world.obstacleX[i] - world.obstacleHalfWidth[i],
          greaterThanOrEqualTo(-_worldEpsilon),
        );
        expect(
          world.obstacleX[i] + world.obstacleHalfWidth[i],
          lessThanOrEqualTo(world.fieldWidth + _worldEpsilon),
        );
      }
    });

    test('relative positions survive a resize unchanged', () {
      final game = Game(seed: 17)
        ..resizeToScreenAspect(_wideAspect)
        ..startRun();
      for (var i = 0; i < 300; i++) {
        game
          ..moveTargetTo(game.world.fieldWidth * 0.5)
          ..advance(_step)
          ..consumeEvents();
      }

      final world = game.world;
      final widthBefore = world.fieldWidth;
      final craftBefore = world.playerX / widthBefore;
      final obstaclesBefore = <double>[
        for (var i = 0; i < world.obstacleCount; i++)
          world.obstacleX[i] / widthBefore,
      ];
      final halfWidthsBefore = <double>[
        for (var i = 0; i < world.obstacleCount; i++)
          world.obstacleHalfWidth[i] / widthBefore,
      ];

      game.resizeToScreenAspect(_narrowAspect);

      final widthAfter = world.fieldWidth;
      expect(widthAfter, lessThan(widthBefore));
      expect(world.playerX / widthAfter, closeTo(craftBefore, _ratioEpsilon));

      for (var i = 0; i < obstaclesBefore.length; i++) {
        expect(
          world.obstacleX[i] / widthAfter,
          closeTo(obstaclesBefore[i], _ratioEpsilon),
          reason: 'obstacle $i drifted relative to the field',
        );
        expect(
          world.obstacleHalfWidth[i] / widthAfter,
          closeTo(halfWidthsBefore[i], _ratioEpsilon),
          reason: 'obstacle $i changed its share of the field',
        );
      }
    });

    test('a resize round trip returns the world to where it started', () {
      final game = Game(seed: 23)
        ..resizeToScreenAspect(_narrowAspect)
        ..startRun();
      for (var i = 0; i < 300; i++) {
        game
          ..moveTargetTo(game.world.fieldWidth * 0.4)
          ..advance(_step)
          ..consumeEvents();
      }

      final world = game.world;
      final craftBefore = world.playerX;
      final obstaclesBefore = <double>[
        for (var i = 0; i < world.obstacleCount; i++) world.obstacleX[i],
      ];

      game
        ..resizeToScreenAspect(_wideAspect)
        ..resizeToScreenAspect(_narrowAspect);

      expect(world.playerX, closeTo(craftBefore, _worldEpsilon));
      for (var i = 0; i < obstaclesBefore.length; i++) {
        expect(world.obstacleX[i], closeTo(obstaclesBefore[i], _worldEpsilon));
      }
    });

    test('resizing mid-run never ends the run by itself', () {
      final game = Game(seed: 31)
        ..resizeToScreenAspect(_narrowAspect)
        ..startRun();

      for (var i = 0; i < 1200; i++) {
        game.resizeToScreenAspect(i.isEven ? _narrowAspect : _wideAspect);
        game
          ..moveTargetTo(game.world.fieldWidth * 0.5)
          ..advance(_step)
          ..consumeEvents();

        final world = game.world;
        expect(
          world.playerX,
          inInclusiveRange(
            game.config.player.radius - _worldEpsilon,
            world.fieldWidth - game.config.player.radius + _worldEpsilon,
          ),
          reason: 'the craft left the field on frame $i',
        );
      }
    });

    test('a resize to the same width changes nothing', () {
      final game = Game(seed: 5)
        ..resizeToScreenAspect(_narrowAspect)
        ..startRun();
      for (var i = 0; i < 200; i++) {
        game
          ..advance(_step)
          ..consumeEvents();
      }

      final world = game.world;
      final craftBefore = world.playerX;
      final firstObstacle = world.obstacleCount > 0 ? world.obstacleX[0] : 0.0;

      game.resizeToScreenAspect(_narrowAspect);

      expect(world.playerX, craftBefore);
      if (world.obstacleCount > 0) {
        expect(world.obstacleX[0], firstObstacle);
      }
    });
  });
}

double _largestFreeSpanAt(WorldView world, double y) {
  final spans = <(double, double)>[];
  for (var i = 0; i < world.obstacleCount; i++) {
    if ((world.obstacleY[i] - y).abs() > world.obstacleHalfHeight[i]) continue;
    spans.add((
      world.obstacleX[i] - world.obstacleHalfWidth[i],
      world.obstacleX[i] + world.obstacleHalfWidth[i],
    ));
  }
  spans.sort((a, b) => a.$1.compareTo(b.$1));

  var cursor = 0.0;
  var widest = 0.0;
  for (final (left, right) in spans) {
    final free = left - cursor;
    if (free > widest) widest = free;
    if (right > cursor) cursor = right;
  }

  final tail = world.fieldWidth - cursor;
  return tail > widest ? tail : widest;
}
