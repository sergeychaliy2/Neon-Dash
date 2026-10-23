import 'package:playable_core/playable_core.dart';
import 'package:playable_kit/playable_kit.dart';
import 'package:playable_core/src/application/simulation.dart';
import 'package:playable_core/src/application/world.dart';
import 'package:test/test.dart';

const double _phoneAspect = 0.45;
const double _step = 1.0 / 120.0;

void main() {
  group('The gates themselves', () {
    test('every kind says what it does and what it is called', () {
      for (final kind in PortalKind.values) {
        expect(kind.title, isNotEmpty, reason: kind.name);
        expect(kind.seconds, greaterThan(0.0), reason: kind.name);
        expect(kind.scrollScale, greaterThan(0.0), reason: kind.name);
        expect(kind.radiusScale, greaterThan(0.0), reason: kind.name);
        expect(kind.scoreScale, greaterThan(0.0), reason: kind.name);
      }
    });

    test('anything that costs reaction time pays for it', () {
      for (final kind in PortalKind.values) {
        if (kind.scrollScale <= 1.0 && !kind.mirrors) continue;
        expect(kind.scoreScale, greaterThan(1.0), reason: kind.name);
      }
    });

    test('exactly one kind swaps the controls', () {
      final mirrors = PortalKind.values.where((kind) => kind.mirrors);

      expect(mirrors, hasLength(1),
          reason: 'two overlapping control flips would be unreadable');
    });
  });

  group('Flying through one', () {
    test('a stretch begins when the craft reaches the gate', () {
      final world = _runningWorld()
        ..addPortal(y: world0, kind: PortalKind.rush);
      expect(world.portal, isNull);

      _runUntil(world, (w) => w.portal != null);

      expect(world.portal, PortalKind.rush);
      expect(world.portalRemaining, closeTo(PortalKind.rush.seconds, 0.05));
      expect(world.portalCount, 0, reason: 'and the gate is behind us');
    });

    test('it runs out on its own', () {
      final world = _runningWorld(_openConfig())
        ..beginPortal(PortalKind.crawl);
      final simulation = _simulation(_openConfig());

      final steps = ((PortalKind.crawl.seconds + 0.2) / _step).round();
      for (var i = 0; i < steps; i++) {
        simulation.step(world);
      }

      expect(world.portal, isNull);
      expect(world.portalRemaining, 0.0);
    });

    test('a second gate replaces the first rather than stacking', () {
      final world = _runningWorld()
        ..beginPortal(PortalKind.rush)
        ..beginPortal(PortalKind.crawl);

      expect(world.portal, PortalKind.crawl);
      expect(world.portalRemaining, closeTo(PortalKind.crawl.seconds, 1e-9));
    });

    test('a gate that is never reached is dropped at the bottom', () {
      final world = _runningWorld()
        ..addPortal(y: world0, kind: PortalKind.shrink);
      world.phase = GamePhase.running;

      _runUntil(world, (w) => w.portalCount == 0);

      expect(world.portal, isNotNull, reason: 'it was crossed, not lost');
    });
  });

  group('What a stretch changes', () {
    test('rush makes the world come faster and crawl slows it', () {
      final rush = _flownFor(PortalKind.rush);
      final crawl = _flownFor(PortalKind.crawl);
      final plain = _flownFor(null);

      expect(rush, greaterThan(plain));
      expect(crawl, lessThan(plain));
    });

    test('rush pays for the time it takes away', () {
      final world = _runningWorld()..beginPortal(PortalKind.rush);
      final plain = _runningWorld();
      final simulation = _simulation();

      for (var i = 0; i < 120; i++) {
        simulation
          ..step(world)
          ..step(plain);
      }

      expect(world.score, greaterThan(plain.score));
    });

    test('shrink makes a smaller target', () {
      final world = _runningWorld();
      final full = world.playerRadius;

      world.beginPortal(PortalKind.shrink);

      expect(world.playerRadius,
          closeTo(full * PortalKind.shrink.radiusScale, 1e-9));
      expect(world.playerRadius, lessThan(full));
    });

    test('a shrunk craft fits through a gap a full one does not', () {
      final small = _runningWorld()..beginPortal(PortalKind.shrink);
      final large = _runningWorld();

      for (final world in <World>[small, large]) {
        final slot = large.playerRadius * 0.8;
        world
          ..addObstacle(
            x: world.playerX - slot - 6.0,
            y: world.playerY,
            halfWidth: 6.0,
            halfHeight: 2.0,
            shape: ObstacleShape.box,
          )
          ..addObstacle(
            x: world.playerX + slot + 6.0,
            y: world.playerY,
            halfWidth: 6.0,
            halfHeight: 2.0,
            shape: ObstacleShape.box,
          );
      }

      _simulation()
        ..step(small)
        ..step(large);

      expect(small.phase, GamePhase.running);
      expect(large.phase, GamePhase.over);
    });

    test('mirror swaps the controls and nothing else', () {
      final world = _runningWorld();
      expect(world.controlsMirrored, isFalse);

      world.beginPortal(PortalKind.mirror);

      expect(world.controlsMirrored, isTrue);
      expect(world.playerRadius, _runningWorld().playerRadius);
    });

    test('a fresh run starts with no gate and no stretch', () {
      final world = _runningWorld()
        ..addPortal(y: -40.0, kind: PortalKind.rush)
        ..beginPortal(PortalKind.mirror);

      world.resetRun();

      expect(world.portal, isNull);
      expect(world.portalCount, 0);
      expect(world.controlsMirrored, isFalse);
    });
  });

  group('Where they come from', () {
    test('a level with no gates never sees one', () {
      final level = LevelCatalogue.levels.firstWhere(
        (candidate) => candidate.portals.isEmpty,
      );
      final game = Game(level: level, seed: 3)
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun();

      for (var i = 0; i < 40000; i++) {
        game
          ..advance(_step)
          ..consumeEvents();
        expect(game.world.portalCount, 0);
        expect(game.world.portal, isNull);
        if (game.world.phase == GamePhase.over) {
          game
            ..restart()
            ..startRun();
        }
      }
    });

    test('a level that offers gates eventually drops one', () {
      final seen = _gatesOf(13, wanted: 1);

      expect(seen.whereType<PortalKind>(), isNotEmpty);
    });

    test('only the kinds a level offers can appear', () {
      final level = LevelCatalogue.byIndex(2);
      expect(level.portals, hasLength(1));

      for (final kind in _gatesOf(2, wanted: 3).whereType<PortalKind>()) {
        expect(level.portals, contains(kind));
      }
    });

    test('the same gate never comes twice in a row', () {
      final seen = _gatesOf(13, wanted: 8);
      expect(seen.whereType<PortalKind>().length, greaterThan(2));

      for (var i = 1; i < seen.length; i++) {
        if (seen[i] == null || seen[i - 1] == null) continue;
        expect(seen[i], isNot(seen[i - 1]), reason: 'two in a row at $i');
      }
    });

    test('the first gate is never in the opening seconds', () {
      final game = Game(
        level: LevelCatalogue.byIndex(13),
        mode: RunMode.shifting,
        seed: 6,
      )
        ..resizeToScreenAspect(_phoneAspect)
        ..startRun();

      for (var i = 0; i < (5.0 / _step).round(); i++) {
        game
          ..advance(_step)
          ..consumeEvents();
        expect(game.world.portal, isNull);
      }
    });
  });

  group('Fairness under a gate', () {
    test('the spacing rules assume the fastest gate a level has', () {
      for (final level in LevelCatalogue.levels) {
        final config = Game(level: level).config;
        final worst = config.portal.worstScrollScale;

        expect(worst, greaterThanOrEqualTo(1.0), reason: level.name);
        for (final kind in level.portals) {
          expect(worst, greaterThanOrEqualTo(kind.scrollScale),
              reason: '${level.name} / ${kind.name}');
        }
      }
    });

    test('a level with no gates assumes nothing', () {
      final level = LevelCatalogue.levels.firstWhere(
        (candidate) => candidate.portals.isEmpty,
      );

      expect(Game(level: level).config.portal.worstScrollScale, 1.0);
    });
  });
}

const double world0 = 79.0;

World _runningWorld([GameConfig? config]) {
  final settings = config ?? GameConfig.neonDash;
  final world = World(settings)
    ..setFieldWidth(
      settings.viewport.widthForScreenAspect(_phoneAspect),
    )
    ..resetRun();

  world.phase = GamePhase.running;
  world.playerTargetX = world.playerX;
  return world;
}

Simulation _simulation([GameConfig? config]) => Simulation(
      config: config ?? GameConfig.neonDash,
      random: DeterministicRandom(1),
      layout: DeterministicRandom(2),
    )..reset();

void _runUntil(World world, bool Function(World world) done) {
  final simulation = _simulation(_openConfig());
  for (var i = 0; i < 20000; i++) {
    if (done(world)) return;
    simulation.step(world);
  }
  fail('never happened');
}

double _flownFor(PortalKind? kind) {
  final world = _runningWorld();
  if (kind != null) world.beginPortal(kind);

  final simulation = _simulation();
  final before = world.distance;
  for (var i = 0; i < 120; i++) {
    simulation.step(world);
  }
  return world.distance - before;
}

List<PortalKind?> _gatesOf(int levelIndex, {required int wanted}) {
  final config = _openConfig(
    portals: LevelCatalogue.byIndex(levelIndex).portals,
  );
  final game = Game(config: config, seed: 17)
    ..resizeToScreenAspect(_phoneAspect)
    ..startRun();
  final world = game.world as World;

  final seen = <PortalKind?>[];

  for (var i = 0; i < 400000 && seen.length < wanted; i++) {
    game.advance(_step);
    for (var p = 0; p < world.portalCount; p++) {
      seen.add(world.portalKindAt(p));
    }
    world.portalCount = 0;
    game.consumeEvents();

    if (world.phase != GamePhase.running) {
      game
        ..restart()
        ..startRun();
      if (seen.isNotEmpty && seen.last != null) seen.add(null);
    }
  }

  return seen;
}

GameConfig _openConfig({Set<PortalKind> portals = const <PortalKind>{}}) =>
    GameConfig(
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
      portal: GameConfig.neonDash.portal.withAvailable(portals),
      orbRadius: GameConfig.neonDash.orbRadius,
      orbChance: 0.0,
      particleLifetime: GameConfig.neonDash.particleLifetime,
      particleSpeed: GameConfig.neonDash.particleSpeed,
      trailCapacity: GameConfig.neonDash.trailCapacity,
      trailSampleInterval: GameConfig.neonDash.trailSampleInterval,
    );
