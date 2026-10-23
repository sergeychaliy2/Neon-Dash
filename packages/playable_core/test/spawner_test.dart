
import 'dart:math' as math;

import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';
import 'package:playable_core/src/application/difficulty_curve.dart';
import 'package:playable_core/src/application/spawner.dart';
import 'package:playable_core/src/application/world.dart';
import 'package:test/test.dart';

const double _phoneAspect = 0.45;

const double _desktopAspect = 1.78;

const double _step = 1.0 / 120.0;

const double _runSeconds = 120.0;

void main() {
  const config = GameConfig.neonDash;

  group('Wave passability', () {
    test('no wave is ever impassable, on the narrowest field', () {
      _expectEveryWavePassable(config, _phoneAspect);
    });

    test('no wave is ever impassable, on the widest field', () {
      _expectEveryWavePassable(config, _desktopAspect);
    });

    test('no level in the catalogue can produce an impassable wave', () {
      for (final level in LevelCatalogue.levels) {
        _expectEveryWavePassable(
          Game(level: level).config,
          _phoneAspect,
          seeds: 4,
          label: level.name,
        );
      }
    });

    test('obstacles enter from above the field rather than popping into it',
        () {
      final world = _freshWorld(config, _phoneAspect);
      final spawner = Spawner(
        config: config,
        random: DeterministicRandom(3),
      )..reset();

      var seen = 0;
      final steps = (_runSeconds / _step).round();
      for (var i = 0; i < steps; i++) {
        world.elapsed += _step;
        final before = world.obstacleCount;
        spawner.update(world, _step);

        for (var j = before; j < world.obstacleCount; j++) {
          seen++;
          expect(
            world.obstacleY[j] + world.obstacleHalfHeight[j],
            lessThanOrEqualTo(0.0),
            reason: 'a spawned obstacle must start entirely above the field',
          );
        }
        if (world.obstacleCount > config.pools.maxObstacles ~/ 2) {
          world.obstacleCount = 0;
        }
      }

      expect(seen, greaterThan(40), reason: 'the run must actually spawn');
    });
  });

  group('Wave variety', () {
    test('every pattern unlocks inside the run it is weighted for', () {
      for (final level in LevelCatalogue.levels) {
        final curve = DifficultyCurve(level.difficulty);

        var travelled = 0.0;
        var seconds = 0.0;
        while (travelled < level.route.firstStageLength && seconds < 600.0) {
          travelled += curve.scrollSpeedAt(seconds) * 0.25;
          seconds += 0.25;
        }

        for (final pattern in level.patterns) {
          expect(
            pattern.unlocksAtSeconds,
            lessThan(seconds * 0.8),
            reason: '${level.name} weights ${pattern.name}, which unlocks at '
                '${pattern.unlocksAtSeconds}s of a run lasting '
                '${seconds.toStringAsFixed(0)}s',
          );
        }
      }
    });

    test('all three shapes appear once their patterns unlock', () {
      final shapes = <ObstacleShape>{};

      for (var seed = 1; seed <= 6 && shapes.length < 3; seed++) {
        final world = _freshWorld(config, _phoneAspect);
        final spawner = Spawner(
          config: config,
          random: DeterministicRandom(seed),
        )..reset();

        final steps = (_runSeconds / _step).round();
        for (var i = 0; i < steps; i++) {
          world.elapsed += _step;
          final before = world.obstacleCount;
          spawner.update(world, _step);
          for (var j = before; j < world.obstacleCount; j++) {
            shapes.add(world.obstacleShapeAt(j));
          }
          world.obstacleCount = 0;
        }
      }

      expect(shapes, containsAll(ObstacleShape.values));
    });

    test('only the starting pattern is used before anything unlocks', () {
      final world = _freshWorld(config, _phoneAspect);
      final spawner = Spawner(
        config: config,
        random: DeterministicRandom(9),
      )..reset();

      final steps =
          (WavePattern.island.unlocksAtSeconds * 0.9 / _step).round();
      for (var i = 0; i < steps; i++) {
        world.elapsed += _step;
        spawner.update(world, _step);
      }

      for (var i = 0; i < world.obstacleCount; i++) {
        expect(world.obstacleShapeAt(i), ObstacleShape.box);
        expect(
          world.obstacleDriftAmplitude[i],
          0.0,
          reason: 'nothing should be moving yet',
        );
      }
      expect(world.obstacleCount, greaterThan(0));
    });

    test('drift stays switched off until its unlock time', () {
      final world = _freshWorld(config, _phoneAspect);
      final spawner = Spawner(
        config: config,
        random: DeterministicRandom(12),
      )..reset();

      final steps =
          (config.wave.driftUnlocksAtSeconds * 0.95 / _step).round();
      for (var i = 0; i < steps; i++) {
        world.elapsed += _step;
        spawner.update(world, _step);
        for (var i = 0; i < world.obstacleCount; i++) {
          if (world.obstacleShapeAt(i) == ObstacleShape.mine) continue;
          expect(world.obstacleDriftAmplitude[i], 0.0);
        }
        world.obstacleCount = 0;
      }
    });
  });

  group('Pattern weights', () {
    test('an empty weight map means everything, equally', () {
      final wave = config.wave;
      for (final pattern in WavePattern.values) {
        expect(wave.weightOf(pattern), 1.0, reason: pattern.name);
      }
    });

    test('a pattern a level does not list has no weight', () {
      final wave = config.wave.copyWith(
        patternWeights: const <WavePattern, double>{
          WavePattern.sides: 1.0,
          WavePattern.island: 9.0,
        },
      );

      expect(wave.weightOf(WavePattern.island), 9.0);
      expect(wave.weightOf(WavePattern.gate), 0.0);
    });

    test('a level only ever shows the patterns it weights', () {
      final weighted = GameConfig(
        viewport: config.viewport,
        player: config.player,
        difficulty: config.difficulty,
        score: config.score,
        pools: config.pools,
        simulation: config.simulation,
        wave: config.wave.copyWith(
          patternWeights: const <WavePattern, double>{WavePattern.mines: 1.0},
        ),
        route: config.route,
        bonus: GameConfig.neonDash.bonus,
        portal: GameConfig.neonDash.portal,
        orbRadius: config.orbRadius,
        orbChance: config.orbChance,
        particleLifetime: config.particleLifetime,
        particleSpeed: config.particleSpeed,
        trailCapacity: config.trailCapacity,
        trailSampleInterval: config.trailSampleInterval,
      );

      final world = _freshWorld(weighted, _phoneAspect);
      world.elapsed = 120.0;
      final spawner = Spawner(
        config: weighted,
        random: DeterministicRandom(4),
      )..reset();

      var seen = 0;
      for (var i = 0; i < (60.0 / _step).round(); i++) {
        world.elapsed += _step;
        final before = world.obstacleCount;
        spawner.update(world, _step);

        for (var j = before; j < world.obstacleCount; j++) {
          seen++;
          expect(world.obstacleShapeAt(j), ObstacleShape.mine);
        }
        world.obstacleCount = 0;
      }

      expect(seen, greaterThan(20), reason: 'the level has to spawn at all');
    });
  });

  group('Wave spacing', () {
    test('waves stay further apart than the deepest one is tall', () {
      final curve = DifficultyCurve(config.difficulty);
      final wave = config.wave;

      final mineStagger =
          wave.mineRadius + (wave.minesPerWave - 1) * wave.mineRadius * 2.6;
      var deepest = wave.boxHalfHeight * 2.0;
      for (final depth in <double>[
        wave.pylonHalfHeight * 2.0,
        wave.spikeHalfHeight * 2.0,
        mineStagger + wave.mineRadius,
      ]) {
        if (depth > deepest) deepest = depth;
      }

      for (var elapsed = 0.0; elapsed <= 200.0; elapsed += 0.5) {
        final spacing = Spawner.alignToBeat(
              curve.spawnIntervalAt(elapsed),
              kBeatSeconds,
            ) *
            curve.scrollSpeedAt(elapsed);
        expect(
          spacing,
          greaterThan(deepest),
          reason: 'at t=$elapsed waves would overlap vertically',
        );
      }
    });

    test('the spawn interval is always a whole number of beats', () {
      for (final level in LevelCatalogue.levels) {
        final beat = level.music.beatSeconds;
        for (var seconds = 0.05; seconds <= 4.0; seconds += 0.05) {
          final aligned = Spawner.alignToBeat(seconds, beat);
          final beats = aligned / beat;

          expect(beats, closeTo(beats.roundToDouble(), 1e-9));
          expect(beats, greaterThanOrEqualTo(1.0), reason: 'never zero beats');
        }
      }
    });
  });

  group('Weave timing', () {
    test('the free span, not the spacing, is what has to cover the crossing',
        () {
      const craftSpeed = 1.75 * 45.0;
      final wave = config.wave;
      final blocked = 2.0 * wave.boxHalfHeight;

      for (var crossing = 0.0; crossing <= 70.0; crossing += 1.0) {
        for (var scroll = 20.0; scroll <= 120.0; scroll += 5.0) {
          final spacing = Spawner.weaveSpacing(
            crossing: crossing,
            craftSpeed: craftSpeed,
            scrollSpeed: scroll,
            safetyFactor: wave.weaveSafetyFactor,
            minimum: wave.weaveMinSpacing,
            blockedDepth: blocked,
            reactionSeconds: wave.reactionSeconds,
          );

          expect(
            (spacing - blocked) / scroll,
            greaterThanOrEqualTo(crossing / craftSpeed),
            reason: 'crossing $crossing at scroll $scroll is not reachable',
          );
        }
      }
    });

    test('a crossing is given time to be seen as well as time to be flown',
        () {
      const craftSpeed = 1.75 * 45.0;
      final wave = config.wave;
      final blocked = 2.0 * wave.boxHalfHeight;

      for (var crossing = 0.0; crossing <= 70.0; crossing += 2.0) {
        for (var scroll = 20.0; scroll <= 120.0; scroll += 5.0) {
          final spacing = Spawner.weaveSpacing(
            crossing: crossing,
            craftSpeed: craftSpeed,
            scrollSpeed: scroll,
            safetyFactor: wave.weaveSafetyFactor,
            minimum: wave.weaveMinSpacing,
            blockedDepth: blocked,
            reactionSeconds: wave.reactionSeconds,
          );

          expect(
            (spacing - blocked) / scroll,
            greaterThanOrEqualTo(
              wave.reactionSeconds + crossing / craftSpeed - 1e-9,
            ),
            reason: 'crossing $crossing at scroll $scroll leaves no time to '
                'react before the flight has to start',
          );
        }
      }
    });

    test('spacing never drops below its floor', () {
      expect(
        Spawner.weaveSpacing(
          crossing: 0.0,
          craftSpeed: 100.0,
          scrollSpeed: 20.0,
          safetyFactor: 1.7,
          minimum: 20.0,
          blockedDepth: 4.0,
          reactionSeconds: 0.24,
        ),
        20.0,
      );
    });

    test('a craft that cannot move gets the floor rather than infinity', () {
      expect(
        Spawner.weaveSpacing(
          crossing: 10.0,
          craftSpeed: 0.0,
          scrollSpeed: 50.0,
          safetyFactor: 1.7,
          minimum: 20.0,
          blockedDepth: 4.0,
          reactionSeconds: 0.24,
        ),
        20.0,
      );
    });
  });

  group('Every level can be flown', () {
    test('from the first row to the last, on a phone', () {
      for (final level in LevelCatalogue.levels) {
        _expectLevelFlyable(
          Game(level: level).config,
          _phoneAspect,
          seconds: level.routeSeconds,
          seeds: 12,
          label: level.name,
        );
      }
    });

    test('and on the widest field', () {
      for (final level in LevelCatalogue.levels) {
        _expectLevelFlyable(
          Game(level: level).config,
          _desktopAspect,
          seconds: level.routeSeconds,
          seeds: 5,
          label: '${level.name} wide',
        );
      }
    });
  });

  group('Difficulty curve', () {
    final curve = DifficultyCurve(config.difficulty);

    test('the distance it covers is the integral of the speed it reports', () {
      for (final level in LevelCatalogue.levels) {
        final pace = level.difficulty;
        final walked = DifficultyCurve(pace);

        var summed = 0.0;
        const dt = 1.0 / 240.0;
        final steps = (level.routeSeconds / dt).round();
        for (var i = 0; i < steps; i++) {
          summed += walked.scrollSpeedAt((i + 0.5) * dt) * dt;
        }

        expect(
          pace.distanceOver(level.routeSeconds),
          closeTo(summed, summed * 1e-6 + 1e-6),
          reason: '${level.name}: the closed form and the simulated sum '
              'disagree about how far ${level.routeSeconds}s goes',
        );
      }
    });

    test('starts at the configured starting values', () {
      expect(curve.scrollSpeedAt(0.0), config.difficulty.startScrollSpeed);
      expect(curve.spawnIntervalAt(0.0), config.difficulty.startSpawnInterval);
      expect(curve.gapFractionAt(0.0), config.difficulty.startGapFraction);
    });

    test('holds at its limits past the ramp', () {
      const farFuture = 10000.0;

      expect(curve.scrollSpeedAt(farFuture), config.difficulty.maxScrollSpeed);
      expect(
        curve.spawnIntervalAt(farFuture),
        config.difficulty.minSpawnInterval,
      );
      expect(curve.gapFractionAt(farFuture), config.difficulty.minGapFraction);
    });

    test('speed rises and gap shrinks monotonically', () {
      var previousSpeed = curve.scrollSpeedAt(0.0);
      var previousGap = curve.gapFractionAt(0.0);

      for (var elapsed = 0.5; elapsed <= 200.0; elapsed += 0.5) {
        final speed = curve.scrollSpeedAt(elapsed);
        final gap = curve.gapFractionAt(elapsed);

        expect(speed, greaterThanOrEqualTo(previousSpeed));
        expect(gap, lessThanOrEqualTo(previousGap));

        previousSpeed = speed;
        previousGap = gap;
      }
    });

    test('speed stops rising at its ceiling', () {
      expect(
        curve.scrollSpeedAt(1e6),
        config.difficulty.maxScrollSpeed,
      );
    });

    test('negative time is treated as the start of the run', () {
      expect(curve.scrollSpeedAt(-5.0), config.difficulty.startScrollSpeed);
    });
  });
}

World _freshWorld(GameConfig config, double screenAspect) {
  final world = World(config)
    ..setFieldWidth(config.viewport.widthForScreenAspect(screenAspect))
    ..resetRun();
  world.phase = GamePhase.running;
  return world;
}

void _expectEveryWavePassable(
  GameConfig config,
  double screenAspect, {
  int seeds = 20,
  String label = '',
}) {
  final steps = (_runSeconds / _step).round();
  final craftDiameter = config.player.radius * 2.0;

  for (var seed = 1; seed <= seeds; seed++) {
    final world = _freshWorld(config, screenAspect);
    final spawner = Spawner(
      config: config,
      random: DeterministicRandom(seed),
    )..reset();

    for (var i = 0; i < steps; i++) {
      world.elapsed += _step;
      final before = world.obstacleCount;
      spawner.update(world, _step);
      if (world.obstacleCount == before) continue;

      for (var depthAt = before; depthAt < world.obstacleCount; depthAt++) {
        final gap = _worstCaseFreeSpan(
          world,
          world.obstacleY[depthAt],
          before,
          world.obstacleCount,
        );
        expect(
          gap,
          greaterThanOrEqualTo(craftDiameter),
          reason: '$label seed $seed at '
              't=${world.elapsed.toStringAsFixed(1)}s, '
              'depth ${world.obstacleY[depthAt].toStringAsFixed(1)}, '
              'left no way through',
        );
      }

      world.obstacleCount = 0;
      world.orbCount = 0;
    }
  }
}

void _expectLevelFlyable(
  GameConfig config,
  double screenAspect, {
  required double seconds,
  int seeds = 4,
  String label = '',
}) {
  final steps = (seconds / _step).round();
  final curve = DifficultyCurve(config.difficulty);
  final radius = config.player.radius;
  final reaction = config.wave.reactionSeconds;

  for (var seed = 1; seed <= seeds; seed++) {
    final world = _freshWorld(config, screenAspect);
    final spawner = Spawner(
      config: config,
      random: DeterministicRandom(seed),
    )..reset();

    final craftSpeed = config.player.speedInWidths * world.fieldWidth;
    final left = radius;
    final right = world.fieldWidth - radius;

    var reachable = <(double, double)>[(left, right)];
    var havePrevious = false;
    var previousTrailingArrival = 0.0;
    var rowsSeen = 0;

    for (var i = 0; i < steps; i++) {
      final scroll =
          curve.scrollSpeedAt(world.elapsed) * config.portal.worstScrollScale;

      world.distance += scroll * _step;
      world.elapsed += _step;

      final before = world.obstacleCount;
      spawner.update(world, _step);
      if (world.obstacleCount == before) continue;

      final depths = <double>[];
      for (var j = before; j < world.obstacleCount; j++) {
        final y = world.obstacleY[j];
        if (!depths.any((other) => (other - y).abs() <= 1e-6)) depths.add(y);
      }
      depths.sort((a, b) => b.compareTo(a));

      for (final depth in depths) {
        var leading = depth;
        var trailing = depth;
        for (var j = before; j < world.obstacleCount; j++) {
          final halfHeight = world.obstacleHalfHeight[j];
          if ((world.obstacleY[j] - depth).abs() > halfHeight) continue;
          final low = world.obstacleY[j] + halfHeight;
          final high = world.obstacleY[j] - halfHeight;
          if (low > leading) leading = low;
          if (high < trailing) trailing = high;
        }

        final leadingArrival = world.distance + (world.playerY - leading);
        final trailingArrival = world.distance + (world.playerY - trailing);

        final stands = _standRanges(
          world,
          depth,
          before,
          world.obstacleCount,
          radius,
        );

        if (havePrevious && scroll > 0.0) {
          final free = leadingArrival - previousTrailingArrival;
          final travel = free <= 0.0
              ? 0.0
              : math.max(0.0, free / scroll - reaction) * craftSpeed;
          reachable = _widened(reachable, travel, left, right);
        }

        reachable = _narrowedTo(reachable, stands);

        expect(
          reachable,
          isNotEmpty,
          reason: '$label seed $seed at '
              't=${world.elapsed.toStringAsFixed(1)}s: the row at depth '
              '${depth.toStringAsFixed(1)} cannot be reached from anywhere '
              'the craft could still have been',
        );

        havePrevious = true;
        previousTrailingArrival = trailingArrival;
        rowsSeen++;
      }

      world.obstacleCount = 0;
      world.orbCount = 0;
      world.pickupCount = 0;
    }

    expect(
      rowsSeen,
      greaterThan(20),
      reason: '$label seed $seed produced only $rowsSeen rows in '
          '${seconds.toStringAsFixed(0)}s, which is not a level',
    );
  }
}

List<(double, double)> _standRanges(
  World world,
  double depth,
  int from,
  int to,
  double radius,
) {
  final blocked = <(double, double)>[];
  for (var i = from; i < to; i++) {
    if ((world.obstacleY[i] - depth).abs() > world.obstacleHalfHeight[i]) {
      continue;
    }
    final reach = world.obstacleHalfWidth[i] + world.obstacleDriftAmplitude[i];
    blocked.add((world.obstacleHomeX[i] - reach, world.obstacleHomeX[i] + reach));
  }
  blocked.sort((a, b) => a.$1.compareTo(b.$1));

  final stands = <(double, double)>[];
  var cursor = 0.0;
  for (final (blockFrom, blockTo) in blocked) {
    if (blockFrom > cursor) _addStand(stands, cursor, blockFrom, radius);
    if (blockTo > cursor) cursor = blockTo;
  }
  _addStand(stands, cursor, world.fieldWidth, radius);

  return stands;
}

void _addStand(
  List<(double, double)> into,
  double spanFrom,
  double spanTo,
  double radius,
) {
  final standFrom = spanFrom + radius;
  final standTo = spanTo - radius;
  if (standTo >= standFrom) into.add((standFrom, standTo));
}

List<(double, double)> _widened(
  List<(double, double)> ranges,
  double travel,
  double left,
  double right,
) {
  final grown = <(double, double)>[];

  for (final (from, to) in ranges) {
    var low = from - travel;
    var high = to + travel;
    if (low < left) low = left;
    if (high > right) high = right;
    if (high < low) continue;

    if (grown.isNotEmpty && low <= grown.last.$2) {
      final merged = grown.removeLast();
      grown.add((merged.$1, high > merged.$2 ? high : merged.$2));
    } else {
      grown.add((low, high));
    }
  }

  return grown;
}

List<(double, double)> _narrowedTo(
  List<(double, double)> ranges,
  List<(double, double)> allowed,
) {
  final kept = <(double, double)>[];
  var a = 0;
  var b = 0;

  while (a < ranges.length && b < allowed.length) {
    final low = math.max(ranges[a].$1, allowed[b].$1);
    final high = math.min(ranges[a].$2, allowed[b].$2);
    if (high >= low) kept.add((low, high));

    if (ranges[a].$2 < allowed[b].$2) {
      a++;
    } else {
      b++;
    }
  }

  return kept;
}

double _worstCaseFreeSpan(World world, double depth, int from, int to) =>
    _widestFreeSpan(world, depth, from, to).width;

({double width, double left, double right}) _widestFreeSpan(
  World world,
  double depth,
  int from,
  int to,
) {
  final spans = <(double, double)>[];
  for (var i = from; i < to; i++) {
    if ((world.obstacleY[i] - depth).abs() > world.obstacleHalfHeight[i]) {
      continue;
    }
    final reach = world.obstacleHalfWidth[i] + world.obstacleDriftAmplitude[i];
    spans.add((world.obstacleHomeX[i] - reach, world.obstacleHomeX[i] + reach));
  }
  spans.sort((a, b) => a.$1.compareTo(b.$1));

  var cursor = 0.0;
  var widest = 0.0;
  var spanLeft = 0.0;
  for (final (left, right) in spans) {
    final free = left - cursor;
    if (free > widest) {
      widest = free;
      spanLeft = cursor;
    }
    if (right > cursor) cursor = right;
  }

  final tail = world.fieldWidth - cursor;
  if (tail > widest) {
    widest = tail;
    spanLeft = cursor;
  }
  return (width: widest, left: spanLeft, right: spanLeft + widest);
}
