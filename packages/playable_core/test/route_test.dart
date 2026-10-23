import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';
import 'package:playable_core/src/application/simulation.dart';
import 'package:playable_core/src/application/world.dart';
import 'package:test/test.dart';

const double _phoneAspect = 0.45;
const double _step = 1.0 / 120.0;

void main() {
  group('Route shape', () {
    test('a distance maps to the segment that contains it', () {
      final route = Route.forStage(3);

      for (var i = 0; i < route.segmentCount; i++) {
        final start = route.segmentStart[i];
        final end = route.segmentEnd(i);
        expect(route.segmentAt(start), i);
        expect(route.segmentAt((start + end) * 0.5), i);
      }
      expect(route.segmentAt(-10.0), 0);
      expect(route.segmentAt(route.length * 2.0), route.segmentCount - 1);
    });

    test('a stage is the same shape every time it is built', () {
      for (var stage = 1; stage <= 8; stage++) {
        final first = Route.forStage(stage);
        final second = Route.forStage(stage);

        expect(second.length, first.length);
        expect(second.segmentStart, first.segmentStart);
        expect(second.segmentClassIndex, first.segmentClassIndex);
        expect(second.checkpointDistance, first.checkpointDistance);
      }
    });

    test('different stages differ', () {
      final shapes = <String>{
        for (var stage = 1; stage <= 8; stage++)
          Route.forStage(stage).segmentClassIndex.join(','),
      };

      expect(shapes.length, greaterThan(4));
    });

    test('length grows per stage and then holds at the cap', () {
      const config = RouteConfig.neonDash;
      var previous = 0.0;

      for (var stage = 1; stage <= 40; stage++) {
        final length = Route.forStage(stage).length;
        expect(length, greaterThanOrEqualTo(previous));
        expect(length, lessThanOrEqualTo(config.maxStageLength));
        previous = length;
      }

      expect(previous, config.maxStageLength, reason: 'the cap is reachable');
      expect(Route.forStage(1).length, config.firstStageLength);
    });

    test('segments start at zero, ascend, and stay inside the stage', () {
      for (var stage = 1; stage <= 10; stage++) {
        final route = Route.forStage(stage);

        expect(route.segmentStart[0], 0.0);
        expect(route.segmentCount, greaterThan(1));

        for (var i = 1; i < route.segmentCount; i++) {
          expect(route.segmentStart[i], greaterThan(route.segmentStart[i - 1]));
          expect(route.segmentStart[i], lessThan(route.length));
        }
        expect(route.segmentEnd(route.segmentCount - 1), route.length);
      }
    });

    test('a stage always opens on a moderate stretch', () {
      for (var stage = 1; stage <= 20; stage++) {
        expect(Route.forStage(stage).classOfSegment(0), HazardClass.moderate);
      }
    });

    test('two dense stretches never follow each other', () {
      for (var stage = 1; stage <= 25; stage++) {
        final route = Route.forStage(stage);

        for (var i = 1; i < route.segmentCount; i++) {
          if (route.classOfSegment(i) != HazardClass.dense) continue;
          expect(
            route.classOfSegment(i - 1),
            isNot(HazardClass.dense),
            reason: 'stage $stage runs two dense stretches together at $i',
          );
        }
      }
    });

    test('later stages lean denser', () {
      double denseShare(int stage) {
        final route = Route.forStage(stage);
        var dense = 0;
        for (var i = 0; i < route.segmentCount; i++) {
          if (route.classOfSegment(i) == HazardClass.dense) dense++;
        }
        return dense / route.segmentCount;
      }

      var early = 0.0;
      var late = 0.0;
      for (var stage = 1; stage <= 4; stage++) {
        early += denseShare(stage);
      }
      for (var stage = 12; stage <= 15; stage++) {
        late += denseShare(stage);
      }

      expect(late, greaterThan(early));
    });

    test('checkpoints ascend and sit strictly inside the stage', () {
      const config = RouteConfig.neonDash;

      for (var stage = 1; stage <= 10; stage++) {
        final route = Route.forStage(stage);

        expect(route.checkpointCount, config.checkpointCount);
        expect(route.checkpointDistance.first, greaterThan(0.0));
        expect(route.checkpointDistance.last, lessThan(route.length));

        for (var i = 1; i < route.checkpointCount; i++) {
          expect(
            route.checkpointDistance[i],
            greaterThan(route.checkpointDistance[i - 1]),
          );
        }
      }
    });

    test('progress clamps to the unit interval', () {
      final route = Route.forStage(1);

      expect(route.progressAt(-100.0), 0.0);
      expect(route.progressAt(0.0), 0.0);
      expect(route.progressAt(route.length * 0.5), closeTo(0.5, 1e-6));
      expect(route.progressAt(route.length * 10.0), 1.0);
    });

    test('a stage below one is treated as the first', () {
      expect(Route.forStage(0).stage, 1);
      expect(Route.forStage(-5).length, Route.forStage(1).length);
    });
  });

  group('Running a route', () {
    test('the start screen does not eat into the stage', () {
      final game = Game()..resizeToScreenAspect(_phoneAspect);

      for (var i = 0; i < 300; i++) {
        game.advance(_step);
      }

      expect(game.world.distance, greaterThan(0.0));
      expect(game.world.routeDistance, 0.0);
      expect(game.world.routeProgress, 0.0);
    });

    test('checkpoints are banked in order, once each', () {
      final game = _openGame(5);
      final route = game.world.route;
      var banked = 0;

      for (var i = 0; i < 40000 && game.world.phase == GamePhase.running; i++) {
        game.advance(_step);

        for (var e = 0; e < game.world.eventCount; e++) {
          if (game.world.eventAt(e) != GameEvent.checkpointPassed) continue;
          banked++;
          expect(game.world.checkpointsPassed, banked);
          expect(
            game.world.routeDistance,
            greaterThanOrEqualTo(route.checkpointDistance[banked - 1]),
          );
        }
        game.consumeEvents();
      }

      expect(game.world.phase, GamePhase.finished);
      expect(banked, route.checkpointCount);
    });

    test('crossing the finish ends the stage as a win', () {
      final game = _openGame(3);
      final world = game.world;
      var cleared = false;

      for (var i = 0; i < 40000 && !cleared; i++) {
        game.advance(_step);
        for (var e = 0; e < world.eventCount; e++) {
          if (world.eventAt(e) == GameEvent.stageCleared) cleared = true;
        }
        game.consumeEvents();
      }

      expect(cleared, isTrue);
      expect(world.phase, GamePhase.finished);
      expect(world.routeProgress, 1.0);
      expect(world.checkpointsPassed, world.route.checkpointCount);
    });

    test('a crash on the finish line is a crash, not a win', () {
      final config = _openRouteConfig();
      final world = World(config)
        ..setFieldWidth(config.viewport.widthForScreenAspect(_phoneAspect))
        ..resetRun();
      world.phase = GamePhase.running;
      world.playerTargetX = world.playerX;
      world.routeDistance = world.route.length - 0.01;
      world.addObstacle(
        x: world.playerX,
        y: world.playerY,
        halfWidth: 6.0,
        halfHeight: 3.0,
        shape: ObstacleShape.box,
      );

      Simulation(config: config, random: DeterministicRandom(1)).step(world);

      expect(world.phase, GamePhase.over);
    });

    test('loading a stage rewinds progress', () {
      final game = _openGame(1);
      for (var i = 0; i < 2000; i++) {
        game
          ..advance(_step)
          ..consumeEvents();
      }
      expect(game.world.routeDistance, greaterThan(0.0));

      game.loadStage(4);

      expect(game.stage, 4);
      expect(game.world.routeDistance, 0.0);
      expect(game.world.checkpointsPassed, 0);
      expect(game.world.phase, GamePhase.ready);
      expect(game.world.route.length, Route.forStage(4).length);
    });

    test('the hazard class follows the craft along the route', () {
      final seen = <HazardClass>{};

      for (var stage = 1; stage <= 4; stage++) {
        final game = _openGame(stage);
        final route = game.world.route;

        for (var i = 0;
            i < 40000 && game.world.phase == GamePhase.running;
            i++) {
          game
            ..advance(_step)
            ..consumeEvents();
          seen.add(game.world.hazard);

          if (i % 97 == 0) {
            expect(
              game.world.hazard,
              route.classOfSegment(
                route.segmentAt(game.world.routeDistance),
              ),
            );
          }
        }

        expect(game.world.phase, GamePhase.finished);
      }

      expect(seen.length, greaterThan(1), reason: 'the texture must change');
    });
  });
}

Game _openGame(int stage) => Game(config: _openRouteConfig(), seed: 7)
  ..resizeToScreenAspect(_phoneAspect)
  ..loadStage(stage)
  ..startRun()
  ..consumeEvents();

GameConfig _openRouteConfig() => GameConfig(
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
