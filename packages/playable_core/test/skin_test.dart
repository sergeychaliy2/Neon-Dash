import 'package:playable_core/playable_core.dart';
import 'package:test/test.dart';

void main() {
  group('Owning a hull', () {
    test('a fresh profile wears the standard hull and owns only that', () {
      final profile = Progression();

      expect(profile.selectedSkin, CraftSkin.standard);
      expect(profile.skins, <CraftSkin>{CraftSkin.standard});
      expect(profile.ownsSkin(CraftSkin.standard), isTrue);
      expect(profile.ownsSkin(CraftSkin.prism), isFalse);
    });

    test('the standard hull is never for sale', () {
      expect(CraftSkin.standard.price, 0);
      expect(CraftSkin.standard.isPurchasable, isFalse);
      expect(Progression(shards: 9999).canAffordSkin(CraftSkin.standard),
          isFalse);
    });

    test('every other hull costs something and describes itself', () {
      for (final skin in CraftSkin.values) {
        if (skin == CraftSkin.standard) continue;
        expect(skin.price, greaterThan(0), reason: skin.name);
        expect(skin.title, isNotEmpty, reason: skin.name);
        expect(skin.detail, isNotEmpty, reason: skin.name);
      }
    });

    test('buying one wears it immediately', () {
      final profile = Progression(shards: 1000);

      expect(profile.buySkin(CraftSkin.lance), isTrue);

      expect(profile.selectedSkin, CraftSkin.lance);
      expect(profile.shards, 1000 - CraftSkin.lance.price);
    });

    test('a hull nobody can afford is not sold', () {
      final profile = Progression(shards: CraftSkin.prism.price - 1);

      expect(profile.buySkin(CraftSkin.prism), isFalse);
      expect(profile.ownsSkin(CraftSkin.prism), isFalse);
      expect(profile.shards, CraftSkin.prism.price - 1);
    });

    test('a hull is never bought twice', () {
      final profile = Progression(shards: 5000)..buySkin(CraftSkin.kite);
      final left = profile.shards;

      expect(profile.buySkin(CraftSkin.kite), isFalse);
      expect(profile.shards, left);
    });

    test('switching back to an owned hull is free', () {
      final profile = Progression(shards: 1000)..buySkin(CraftSkin.halo);
      final left = profile.shards;

      expect(profile.selectSkin(CraftSkin.standard), isTrue);

      expect(profile.selectedSkin, CraftSkin.standard);
      expect(profile.shards, left);
    });

    test('a hull nobody owns cannot be worn', () {
      final profile = Progression();

      expect(profile.selectSkin(CraftSkin.prism), isFalse);
      expect(profile.selectedSkin, CraftSkin.standard);
    });
  });

  group('Saving a hull', () {
    test('what is owned and what is worn both survive a round trip', () {
      final profile = Progression(shards: 5000)
        ..buySkin(CraftSkin.lance)
        ..buySkin(CraftSkin.prism)
        ..selectSkin(CraftSkin.lance);

      final restored = Progression.fromJson(profile.toJson());

      expect(restored.selectedSkin, CraftSkin.lance);
      expect(restored.ownsSkin(CraftSkin.prism), isTrue);
      expect(restored.ownsSkin(CraftSkin.kite), isFalse);
      expect(restored.shards, profile.shards);
    });

    test('a save from before hulls existed still opens', () {
      const legacy = '{"version":2,"shards":10,"stars":{"0":2}}';

      final restored = Progression.fromJson(legacy);

      expect(restored.selectedSkin, CraftSkin.standard);
      expect(restored.skins, <CraftSkin>{CraftSkin.standard});
    });

    test('a hull this build has never heard of is ignored', () {
      const fromTheFuture =
          '{"skins":["lance","voidrunner"],"skin":"voidrunner"}';

      final restored = Progression.fromJson(fromTheFuture);

      expect(restored.ownsSkin(CraftSkin.lance), isTrue);
      expect(restored.selectedSkin, CraftSkin.standard,
          reason: 'falls back rather than leaving the craft unpaintable');
    });

    test('the standard hull cannot be edited out of a save', () {
      const stripped = '{"skins":["prism"],"skin":"prism"}';

      final restored = Progression.fromJson(stripped);

      expect(restored.ownsSkin(CraftSkin.standard), isTrue);
    });
  });

  group('Hull balance', () {
    test('no hull is better than another at everything', () {
      for (final hull in CraftSkin.values) {
        for (final other in CraftSkin.values) {
          expect(
            hull.dominates(other),
            isFalse,
            reason: '${hull.name} beats ${other.name} on every axis',
          );
        }
      }
    });

    test('every hull is worth about as much as the standard one', () {
      const slack = 0.15;
      final baseline = CraftSkin.standard.rating;

      for (final hull in CraftSkin.values) {
        expect(
          hull.rating,
          closeTo(baseline, slack),
          reason: '${hull.name} is worth ${hull.rating}, not $baseline',
        );
      }
    });

    test('the standard hull is the standard', () {
      expect(CraftSkin.standard.speedScale, 1.0);
      expect(CraftSkin.standard.gripScale, 1.0);
      expect(CraftSkin.standard.radiusScale, 1.0);
      expect(CraftSkin.standard.shardScale, 1.0);
    });

    test('every hull is good at something and bad at something', () {
      for (final hull in CraftSkin.values) {
        if (hull == CraftSkin.standard) continue;

        final axes = <double>[
          hull.speedScale,
          hull.gripScale,
          2.0 - hull.radiusScale,
          hull.shardScale,
        ];
        expect(axes.any((axis) => axis > 1.02), isTrue,
            reason: '${hull.name} has no strength');
        expect(axes.any((axis) => axis < 0.98), isTrue,
            reason: '${hull.name} has no weakness');
      }
    });

    test('no stat is far enough from one to break a level', () {
      for (final hull in CraftSkin.values) {
        expect(hull.speedScale, inInclusiveRange(0.8, 1.25), reason: hull.name);
        expect(hull.gripScale, inInclusiveRange(0.75, 1.35), reason: hull.name);
        expect(hull.radiusScale, inInclusiveRange(0.75, 1.2),
            reason: hull.name);
        expect(hull.shardScale, inInclusiveRange(0.6, 1.35), reason: hull.name);
      }
    });

    test('a hull reaches the simulation as three multiplied numbers', () {
      const base = PlayerConfig(
        lineY: 80.0,
        radius: 2.0,
        speedInWidths: 1.0,
        followRate: 10.0,
      );

      final flown = base.withHull(CraftSkin.lance);

      expect(flown.radius, closeTo(2.0 * CraftSkin.lance.radiusScale, 1e-9));
      expect(flown.speedInWidths,
          closeTo(1.0 * CraftSkin.lance.speedScale, 1e-9));
      expect(flown.followRate, closeTo(10.0 * CraftSkin.lance.gripScale, 1e-9));
      expect(flown.lineY, base.lineY, reason: 'where it flies does not change');
    });

    test('the hull a game is given is the hull it flies', () {
      final stock = Game(level: LevelCatalogue.byIndex(0));
      final needle = Game(
        level: LevelCatalogue.byIndex(0),
        skin: CraftSkin.lance,
      );

      expect(needle.config.player.radius,
          lessThan(stock.config.player.radius));
      expect(needle.config.player.speedInWidths,
          greaterThan(stock.config.player.speedInWidths));
    });

    test('a hull that pays better really does pay better', () {
      int shardsWith(CraftSkin skin) => RunSummary(
            levelIndex: 0,
            mode: RunMode.fixed,
            finished: true,
            score: 0,
            orbs: 20,
            nearMisses: 0,
            hits: 0,
            progress: 1.0,
            checkpointsPassed: 4,
            continuesUsed: 0,
            bonusesSpent: 0,
            stars: 3,
            shards: (45 * skin.shardScale).round(),
          ).shards;

      expect(shardsWith(CraftSkin.prism), greaterThan(shardsWith(CraftSkin.lance)));
    });
  });

  group('What a hull is made of', () {
    test('every hull has a silhouette that could be drawn', () {
      for (final skin in CraftSkin.values) {
        expect(skin.noseLength, greaterThan(0.0), reason: skin.name);
        expect(skin.tailLength, greaterThan(0.0), reason: skin.name);
        expect(skin.tipReach, greaterThan(0.0), reason: skin.name);
        expect(skin.waist, greaterThan(0.0), reason: skin.name);
        expect(skin.shoulder, greaterThan(0.0), reason: skin.name);
      }
    });

    test('every hull has between one and three thrusters', () {
      for (final skin in CraftSkin.values) {
        expect(skin.exhausts, inInclusiveRange(1, 3), reason: skin.name);
        expect(skin.trailWidthScale, greaterThan(0.0), reason: skin.name);
      }
    });

    test('no two hulls share a shape', () {
      final seen = <String, String>{};

      for (final skin in CraftSkin.values) {
        final shape = '${skin.silhouette.name}/${skin.noseLength}'
            '/${skin.shoulder}/${skin.tipReach}/${skin.tipDrop}'
            '/${skin.waist}/${skin.tailLength}';
        expect(seen.containsKey(shape), isFalse,
            reason: '${skin.name} is shaped exactly like ${seen[shape]}');
        seen[shape] = skin.name;
      }
    });

    test('every silhouette in the enum is actually used', () {
      final used = <HullSilhouette>{
        for (final skin in CraftSkin.values) skin.silhouette,
      };

      expect(used, hasLength(HullSilhouette.values.length));
    });

    test('a hull is keyed by a stable name, not by its wording', () {
      expect(CraftSkin.interceptor.name, 'interceptor');
      expect(CraftSkin.prism.name, 'prism');
    });

    test('only the expensive hulls ignore the level palette', () {
      for (final skin in CraftSkin.values) {
        if (skin.hueOverride == null) continue;
        expect(skin.price, greaterThanOrEqualTo(220), reason: skin.name);
        expect(skin.hueOverride, inInclusiveRange(0.0, 360.0));
      }
    });
  });
}
