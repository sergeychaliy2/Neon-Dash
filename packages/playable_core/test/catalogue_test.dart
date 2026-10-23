import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';
import 'package:playable_core/src/application/spawner.dart';
import 'package:playable_core/src/application/world.dart';
import 'package:test/test.dart';

void main() {
  group('Level catalogue', () {
    test('indices match positions', () {
      for (var i = 0; i < LevelCatalogue.count; i++) {
        expect(LevelCatalogue.levels[i].index, i);
        expect(LevelCatalogue.byIndex(i).name, LevelCatalogue.levels[i].name);
      }
    });

    test('byIndex clamps rather than throwing', () {
      expect(LevelCatalogue.byIndex(-3).index, 0);
      expect(LevelCatalogue.byIndex(999).index, LevelCatalogue.count - 1);
    });

    test('names and taglines are present and unique', () {
      final names = <String>{};
      for (final level in LevelCatalogue.levels) {
        expect(level.name.trim(), isNotEmpty);
        expect(level.tagline.trim(), isNotEmpty);
        expect(names.add(level.name), isTrue, reason: 'duplicate ${level.name}');
      }
    });

    test('every level can eventually be opened', () {
      final progression = Progression();

      for (final level in LevelCatalogue.levels) {
        expect(
          progression.isUnlocked(level),
          isTrue,
          reason: '${level.name} is unreachable even with every earlier '
              'level perfected',
        );
        progression.record(level.index, StarRules.maxPerLevel);
      }
    });

    test('the first level is open and teaches before it tests', () {
      final first = LevelCatalogue.levels.first;

      expect(first.unlock, isA<AlwaysOpen>());

      expect(first.bonuses, hasLength(1));
      expect(first.bonuses.single.isCharge, isTrue,
          reason: 'nothing to manage on the first level');
      expect(
        first.patterns,
        isNot(contains(WavePattern.weave)),
        reason: 'the opening level should not start on the hardest pattern',
      );
    });

    group('The ladder', () {

      void expectRising(
        String what,
        num Function(LevelDefinition level) measure,
      ) {
        for (var i = 1; i < LevelCatalogue.count; i++) {
          final previous = LevelCatalogue.byIndex(i - 1);
          final level = LevelCatalogue.byIndex(i);

          expect(
            measure(level),
            greaterThanOrEqualTo(measure(previous)),
            reason: '$what drops at ${level.name}: '
                '${measure(previous)} then ${measure(level)}',
          );
        }
      }

      test('each level draws from at least as many patterns', () {
        expectRising('pattern count', (level) => level.patterns.length);
      });

      test('each level offers at least as many power-ups', () {
        expectRising('power-up count', (level) => level.bonuses.length);
      });

      test('each level carries at least as many gates', () {
        expectRising('gate count', (level) => level.portals.length);
      });

      test('each level lasts at least as long and is at least as dense', () {
        expectRising('length in seconds', (level) => level.routeSeconds);
        expectRising('density', (level) => level.routeDensity);
      });

      test('a faster level is not a shorter one', () {
        for (final level in LevelCatalogue.levels) {
          final pace = level.difficulty;
          final quicker = DifficultyConfig(
            startScrollSpeed: pace.startScrollSpeed * 1.5,
            maxScrollSpeed: pace.maxScrollSpeed * 1.5,
            speedRampSeconds: pace.speedRampSeconds,
            startSpawnInterval: pace.startSpawnInterval,
            minSpawnInterval: pace.minSpawnInterval,
            spawnRampSeconds: pace.spawnRampSeconds,
            startGapFraction: pace.startGapFraction,
            minGapFraction: pace.minGapFraction,
            gapRampSeconds: pace.gapRampSeconds,
          );

          expect(
            quicker.distanceOver(level.routeSeconds),
            closeTo(pace.distanceOver(level.routeSeconds) * 1.5, 1e-6),
            reason: '${level.name} at half again the speed should cover half '
                'again the ground in the same time',
          );
        }
      });

      test('the walls stop being plain slabs early and stay varied', () {
        final early = LevelCatalogue.levels.take(4);
        final later = LevelCatalogue.levels.skip(4);

        expect(
          early.where((level) => level.theme.trim == ObstacleTrim.plain),
          isNotEmpty,
          reason: 'the opening levels teach the plain shape first',
        );
        expect(
          later.where((level) => level.theme.trim == ObstacleTrim.plain),
          isEmpty,
          reason: 'a plain slab this late is a level that forgot to dress',
        );
        expect(
          later.map((level) => level.theme.trim).toSet(),
          containsAll(<ObstacleTrim>[
            ObstacleTrim.leading,
            ObstacleTrim.trailing,
            ObstacleTrim.both,
          ]),
        );
      });

      test('no two levels in a row light their walls the same way', () {
        for (var i = 1; i < LevelCatalogue.count; i++) {
          final previous = LevelCatalogue.byIndex(i - 1);
          final level = LevelCatalogue.byIndex(i);

          expect(
            level.theme.face,
            isNot(previous.theme.face),
            reason: '${level.name} lights its walls exactly like '
                '${previous.name}',
          );
        }
      });

      test('every way of lighting a wall is used somewhere', () {
        expect(
          LevelCatalogue.levels.map((level) => level.theme.face).toSet(),
          containsAll(WallFace.values),
          reason: 'a face nothing uses is a face nobody will ever see',
        );
      });

      test('the plain slab belongs to the opening levels', () {
        final late = LevelCatalogue.levels.skip(4);

        expect(
          late.where((level) => level.theme.face == WallFace.solid),
          isEmpty,
          reason: 'a plain slab this far in is a level that forgot to dress',
        );
      });

      test('each level asks for at least as many orbs', () {
        expectRising('orb target', (level) => level.stars.orbTarget);
      });

      test('the climb is real, not merely flat', () {
        final first = LevelCatalogue.levels.first;
        final last = LevelCatalogue.levels.last;

        expect(last.patterns.length, greaterThan(first.patterns.length * 2));
        expect(last.bonuses.length, greaterThan(first.bonuses.length));
        expect(last.portals.length, greaterThan(first.portals.length));
      });

      test('the last level holds everything the game has', () {
        final last = LevelCatalogue.levels.last;

        expect(last.patterns, hasLength(WavePattern.values.length));
        expect(last.bonuses, hasLength(BonusKind.values.length));
        expect(last.portals, hasLength(PortalKind.values.length));
      });

      test('the first level holds almost none of it', () {
        final first = LevelCatalogue.levels.first;

        expect(first.portals, isEmpty);
        expect(first.bonuses, hasLength(1));
        expect(first.patterns.length, lessThan(6));
      });
    });

    test('every pattern is weighted by some level', () {
      final weighted = <WavePattern>{};
      for (final level in LevelCatalogue.levels) {
        weighted.addAll(level.patterns);
      }

      expect(weighted, hasLength(WavePattern.values.length));
    });

    test('every obstacle shape reaches the field', () {
      final seen = <ObstacleShape>{};

      for (final level in LevelCatalogue.levels) {
        final config = Game(level: level).config;
        final world = World(config)
          ..setFieldWidth(config.viewport.widthForScreenAspect(0.45))
          ..resetRun();
        world.phase = GamePhase.running;
        final spawner = Spawner(config: config, random: DeterministicRandom(5))
          ..reset();

        for (var i = 0; i < 24000; i++) {
          world.elapsed += 1 / 120;
          spawner.update(world, 1 / 120);
          for (var o = 0; o < world.obstacleCount; o++) {
            seen.add(world.obstacleShapeAt(o));
          }
          world.obstacleCount = 0;
          world.orbCount = 0;
          world.pickupCount = 0;
        }
      }

      expect(seen, hasLength(ObstacleShape.values.length));
    });

    test('every level has something to throw at the player', () {
      for (final level in LevelCatalogue.levels) {
        expect(level.patterns, isNotEmpty, reason: level.name);
        expect(
          level.patterns,
          contains(WavePattern.sides),
          reason: '${level.name} needs the pattern every other one falls '
              'back to when a field is too narrow',
        );
      }
    });

    test('each level leans on its own signature pattern', () {
      final signatures = <WavePattern>{};

      for (final level in LevelCatalogue.levels) {
        signatures.add(level.signaturePattern);
        expect(
          level.patternWeights[WavePattern.sides],
          isNotNull,
          reason: '${level.name} needs the universal fallback',
        );
        expect(level.patternWeights, isNotEmpty, reason: level.name);
      }

      expect(signatures.length, greaterThanOrEqualTo(6));
    });

    test('levels differ in obstacle geometry, not only in pattern choice', () {
      final geometries = <String>{};

      for (final level in LevelCatalogue.levels) {
        final wave = level.wave;
        geometries.add(
          '${wave.boxHalfHeight}/${wave.pylonHalfHeight}/${wave.combSlots}/'
          '${wave.mineRadius}/${wave.spikeHalfWidth}/${wave.zipperTeeth}/'
          '${wave.corridorWidthFraction}/${wave.gateSwingFraction}',
        );
      }

      expect(geometries.length, greaterThanOrEqualTo(6));
    });

    test('palettes have real range, not eight shades of dark blue', () {
      var minLightness = 1.0;
      var maxLightness = 0.0;
      var minSaturation = 1.0;
      var maxSaturation = 0.0;

      for (final level in LevelCatalogue.levels) {
        final sky = level.theme.skyNear;
        if (sky.lightness < minLightness) minLightness = sky.lightness;
        if (sky.lightness > maxLightness) maxLightness = sky.lightness;
        if (sky.saturation < minSaturation) minSaturation = sky.saturation;
        if (sky.saturation > maxSaturation) maxSaturation = sky.saturation;
      }

      expect(maxLightness / minLightness, greaterThan(2.5));
      expect(maxSaturation - minSaturation, greaterThan(0.3));
    });

    test('levels differ from one another in more than name', () {
      final backdrops = <BackdropStyle>{};
      final tempos = <int>{};
      final patternSets = <String>{};
      final craftHues = <double>{};

      for (final level in LevelCatalogue.levels) {
        backdrops.add(level.theme.backdrop);
        tempos.add(level.music.beatsPerMinute);
        patternSets.add(
          (level.patterns.map((p) => p.name).toList()..sort()).join(','),
        );
        craftHues.add(level.theme.craft.hue);
      }

      expect(backdrops.length, greaterThanOrEqualTo(6));
      expect(tempos.length, greaterThanOrEqualTo(6));
      expect(patternSets.length, greaterThanOrEqualTo(6));
      expect(craftHues.length, LevelCatalogue.count);
    });

    test('pacing is sane and the speed ceiling is real', () {
      for (final level in LevelCatalogue.levels) {
        final pace = level.difficulty;

        expect(pace.maxScrollSpeed, greaterThan(pace.startScrollSpeed));
        expect(pace.minSpawnInterval, lessThan(pace.startSpawnInterval));
        expect(pace.minGapFraction, lessThan(pace.startGapFraction));
        expect(pace.minGapFraction, greaterThan(0.2), reason: level.name);
        expect(
          GameConfig.neonDash.player.lineY / pace.maxScrollSpeed,
          greaterThan(0.8),
          reason: '${level.name} leaves too little time to react',
        );
      }
    });

    test('routes are fixed in length, not an endless ladder', () {
      for (final level in LevelCatalogue.levels) {
        final route = Route.forStage(level.stageNumber, config: level.route);

        expect(route.length, level.route.firstStageLength);
        expect(route.length, greaterThan(1000.0));
        expect(route.segmentCount, greaterThan(2), reason: level.name);
        expect(route.checkpointCount, greaterThan(0));
      }
    });

    test('later levels are longer and denser than the first', () {
      final first = LevelCatalogue.levels.first;
      final last = LevelCatalogue.levels.last;

      expect(
        last.route.firstStageLength,
        greaterThan(first.route.firstStageLength),
      );
      expect(last.route.baseDenseChance, greaterThan(first.route.baseDenseChance));
      expect(last.patterns.length, greaterThan(first.patterns.length));
      expect(last.bonuses.length, greaterThan(first.bonuses.length));
    });

    test('star targets are reachable numbers', () {
      for (final level in LevelCatalogue.levels) {
        expect(level.stars.orbTarget, greaterThan(0), reason: level.name);
        expect(level.stars.orbTarget, lessThan(40), reason: level.name);
      }
    });

    test('theme hues stay on the colour wheel', () {
      for (final level in LevelCatalogue.levels) {
        for (final colour in <ThemeColor>[
          level.theme.craft,
          level.theme.orb,
          level.theme.skyFar,
          level.theme.skyNear,
          level.theme.grid,
          level.theme.rail,
        ]) {
          expect(colour.hue, inInclusiveRange(0.0, 360.0), reason: level.name);
          expect(colour.saturation, inInclusiveRange(0.0, 1.0));
          expect(colour.lightness, inInclusiveRange(0.0, 1.0));
          expect(colour.alpha, inInclusiveRange(0.0, 1.0));
        }
      }
    });
  });

  group('Star rules', () {
    const rules = StarRules(orbTarget: 10);

    test('an unfinished run earns nothing', () {
      expect(rules.evaluate(finished: false, orbs: 100, hits: 0), 0);
    });

    test('finishing alone earns one', () {
      expect(rules.evaluate(finished: true, orbs: 0, hits: 3), 1);
    });

    test('the orb target earns a second', () {
      expect(rules.evaluate(finished: true, orbs: 10, hits: 1), 2);
    });

    test('a clean finish earns the third', () {
      expect(rules.evaluate(finished: true, orbs: 10, hits: 0), 3);
      expect(rules.evaluate(finished: true, orbs: 0, hits: 0), 2);
    });

    test('a shielded impact still spends the clean run', () {
      expect(rules.evaluate(finished: true, orbs: 10, hits: 1), 2);
    });
  });

  group('Progression', () {
    test('a fresh profile opens only the first level', () {
      final progression = Progression();

      expect(progression.totalStars, 0);
      expect(progression.shards, 0);
      expect(progression.unlockedCount, 1);
      expect(progression.isUnlocked(LevelCatalogue.levels.first), isTrue);
      expect(progression.isUnlocked(LevelCatalogue.levels[1]), isFalse);
    });

    test('clearing a level opens the one that follows it', () {
      final progression = Progression()..record(0, 1);

      expect(progression.isUnlocked(LevelCatalogue.levels[1]), isTrue);
    });

    test('only an improvement is recorded', () {
      final progression = Progression();

      expect(progression.record(0, 2), isTrue);
      expect(progression.record(0, 1), isFalse);
      expect(progression.starsFor(0), 2);
      expect(progression.record(0, 3), isTrue);
      expect(progression.starsFor(0), 3);
    });

    test('stars are clamped to what a level can award', () {
      final progression = Progression()..record(0, 99);

      expect(progression.starsFor(0), StarRules.maxPerLevel);

      progression.record(1, -5);
      expect(progression.starsFor(1), 0);
    });

    test('star requirements count the whole profile', () {
      final progression = Progression()
        ..record(0, 3)
        ..record(1, 1);
      expect(progression.totalStars, 4);

      final gated = LevelCatalogue.levels[2];
      expect(gated.unlock, isA<StarsRequired>());
      expect(progression.isUnlocked(gated), isTrue);
      expect(progression.starsStillNeeded(gated), 0);
    });

    test('the shortfall is reported for a locked level', () {
      final progression = Progression();
      final locked = LevelCatalogue.levels.last;
      final required = (locked.unlock as StarsRequired).stars;

      expect(progression.starsStillNeeded(locked), required);

      progression.record(0, 3);
      expect(progression.starsStillNeeded(locked), required - 3);
    });

    test('shards add and spend, and refuse to go negative', () {
      final progression = Progression()..addShards(50);
      expect(progression.shards, 50);

      progression.addShards(-10);
      expect(progression.shards, 50, reason: 'negative gifts are ignored');

      expect(progression.spendShards(20), isTrue);
      expect(progression.shards, 30);
      expect(progression.spendShards(100), isFalse);
      expect(progression.shards, 30);
    });

    test('a profile survives a round trip through its save format', () {
      final original = Progression()
        ..record(0, 3)
        ..record(2, 2)
        ..addShards(140);

      final restored = Progression.fromJson(original.toJson());

      expect(restored.starsFor(0), 3);
      expect(restored.starsFor(2), 2);
      expect(restored.starsFor(1), 0);
      expect(restored.totalStars, 5);
      expect(restored.shards, 140);
    });

    test('unreadable save data gives a fresh profile, not a crash', () {
      for (final broken in <String>[
        '',
        'not json',
        '[]',
        '{"stars": "nonsense"}',
        '{"stars": {"a": "b"}, "shards": "lots"}',
      ]) {
        final progression = Progression.fromJson(broken);
        expect(progression.totalStars, 0, reason: broken);
        expect(progression.shards, 0, reason: broken);
      }
    });
  });
}
