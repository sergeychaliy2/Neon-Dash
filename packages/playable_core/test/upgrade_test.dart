import 'package:playable_core/playable_core.dart';
import 'package:playable_core/src/application/world.dart';
import 'package:test/test.dart';

const double _phoneAspect = 0.45;

void main() {
  group('The ladder itself', () {
    test('every upgrade has at least one rank and prices them all', () {
      for (final upgrade in Upgrade.values) {
        expect(upgrade.maxRank, greaterThan(0), reason: upgrade.name);
        expect(upgrade.prices, hasLength(upgrade.maxRank),
            reason: upgrade.name);
        expect(upgrade.title, isNotEmpty, reason: upgrade.name);
        expect(upgrade.detail, isNotEmpty, reason: upgrade.name);
      }
    });

    test('each rank costs more than the last', () {
      for (final upgrade in Upgrade.values) {
        for (var rank = 1; rank < upgrade.maxRank; rank++) {
          expect(
            upgrade.prices[rank],
            greaterThan(upgrade.prices[rank - 1]),
            reason: '${upgrade.name} rank ${rank + 1}',
          );
        }
      }
    });

    test('the slot upgrade can never exceed what the row can hold', () {
      expect(Upgrade.extraSlot.maxRank, 1);
      expect(
        GameConfig.neonDash.bonus.slotCount + Upgrade.extraSlot.maxRank,
        lessThanOrEqualTo(BonusKind.values.length),
      );
    });

    test('the price at the ceiling is zero, meaning nothing left to buy', () {
      for (final upgrade in Upgrade.values) {
        expect(upgrade.priceFrom(upgrade.maxRank), 0, reason: upgrade.name);
        expect(upgrade.priceFrom(0), upgrade.prices.first);
      }
    });

    test('an upgrade is keyed by a stable name, not by its wording', () {
      expect(Upgrade.extraSlot.name, 'extraSlot');
      expect(Upgrade.potency.name, 'potency');
      expect(Upgrade.salvage.name, 'salvage');
    });

    test('fully equipped means every rank of everything', () {
      expect(Achievement.wellEquipped.target, Upgrade.totalRanks);
    });
  });

  group('Buying ranks', () {
    test('a fresh profile owns nothing and can afford nothing', () {
      final profile = Progression();

      for (final upgrade in Upgrade.values) {
        expect(profile.rankOf(upgrade), 0);
        expect(profile.owns(upgrade), isFalse);
        expect(profile.canAfford(upgrade), isFalse);
        expect(profile.buy(upgrade), isFalse);
      }
    });

    test('buying spends exactly the price of the next rank', () {
      final profile = Progression(shards: 10000);
      final first = Upgrade.potency.prices[0];
      final second = Upgrade.potency.prices[1];

      expect(profile.buy(Upgrade.potency), isTrue);
      expect(profile.shards, 10000 - first);
      expect(profile.rankOf(Upgrade.potency), 1);

      expect(profile.buy(Upgrade.potency), isTrue);
      expect(profile.shards, 10000 - first - second);
      expect(profile.rankOf(Upgrade.potency), 2);
    });

    test('a ladder stops at its ceiling', () {
      final profile = Progression(shards: 100000);
      for (var i = 0; i < Upgrade.potency.maxRank; i++) {
        expect(profile.buy(Upgrade.potency), isTrue);
      }
      final left = profile.shards;

      expect(profile.isMaxed(Upgrade.potency), isTrue);
      expect(profile.buy(Upgrade.potency), isFalse);
      expect(profile.shards, left, reason: 'and charges nothing for refusing');
    });

    test('a shard short is still a refusal', () {
      final profile = Progression(
        shards: Upgrade.startingShield.prices.first - 1,
      );

      expect(profile.canAfford(Upgrade.startingShield), isFalse);
      expect(profile.buy(Upgrade.startingShield), isFalse);
    });

    test('affording rank one does not mean affording rank two', () {
      final profile = Progression(shards: Upgrade.potency.prices[0]);
      expect(profile.buy(Upgrade.potency), isTrue);

      expect(profile.shards, 0);
      expect(profile.canAfford(Upgrade.potency), isFalse);
    });
  });

  group('Saving', () {
    test('ranks survive a round trip', () {
      final profile = Progression(shards: 100000)
        ..buy(Upgrade.potency)
        ..buy(Upgrade.potency)
        ..buy(Upgrade.extraSlot)
        ..record(2, 3)
        ..recordScore(2, 4821)
        ..countRun(orbs: 14)
        ..countRun(orbs: 6);

      final restored = Progression.fromJson(profile.toJson());

      expect(restored.rankOf(Upgrade.potency), 2);
      expect(restored.rankOf(Upgrade.extraSlot), 1);
      expect(restored.rankOf(Upgrade.salvage), 0);
      expect(restored.shards, profile.shards);
      expect(restored.starsFor(2), 3);
      expect(restored.bestScoreFor(2), 4821);
      expect(restored.runsPlayed, 2);
      expect(restored.orbsCollected, 20);
    });

    test('a save from before ranks reads as rank one each', () {
      const legacy = '{"version":2,"shards":5,"upgrades":["potency"]}';

      final restored = Progression.fromJson(legacy);

      expect(restored.rankOf(Upgrade.potency), 1);
      expect(restored.owns(Upgrade.potency), isTrue);
    });

    test('a save from the first format still opens', () {
      const legacy = '{"version":1,"shards":42,"stars":{"0":3,"1":2}}';

      final restored = Progression.fromJson(legacy);

      expect(restored.shards, 42);
      expect(restored.starsFor(0), 3);
      expect(restored.runsPlayed, 0);
      expect(restored.loadout.owned, isEmpty);
    });

    test('an upgrade name this build does not know is ignored', () {
      const fromTheFuture =
          '{"shards":5,"upgrades":{"extraSlot":1,"warpDrive":3}}';

      final restored = Progression.fromJson(fromTheFuture);

      expect(restored.rankOf(Upgrade.extraSlot), 1);
      expect(restored.upgradeRanks, 1);
    });

    test('a rank beyond the ceiling is clamped, not trusted', () {
      const forged = '{"upgrades":{"potency":99,"extraSlot":-4}}';

      final restored = Progression.fromJson(forged);

      expect(restored.rankOf(Upgrade.potency), Upgrade.potency.maxRank);
      expect(restored.rankOf(Upgrade.extraSlot), 0);
    });

    test('rubbish in a field costs that field and nothing else', () {
      const damaged =
          '{"shards":"lots","stars":{"0":3},"upgrades":"all","runs":-4}';

      final restored = Progression.fromJson(damaged);

      expect(restored.starsFor(0), 3, reason: 'the readable field survived');
      expect(restored.shards, 0);
      expect(restored.runsPlayed, 0);
      expect(restored.loadout.owned, isEmpty);
    });

    test('a negative star count cannot be smuggled in', () {
      const forged = '{"stars":{"0":-5,"1":99}}';

      final restored = Progression.fromJson(forged);

      expect(restored.starsFor(0), 0);
      expect(restored.starsFor(1), StarRules.maxPerLevel);
    });
  });

  group('Statistics', () {
    test('only an improvement is recorded', () {
      final profile = Progression()
        ..recordScore(0, 900)
        ..recordScore(0, 400);

      expect(profile.bestScoreFor(0), 900);
      expect(profile.recordScore(0, 1200), isTrue);
      expect(profile.bestScoreFor(0), 1200);
    });

    test('the best score spans every level', () {
      final profile = Progression()
        ..recordScore(0, 900)
        ..recordScore(5, 2400);

      expect(profile.bestScore, 2400);
    });

    test('cleared counts levels with a star, not levels played', () {
      final profile = Progression()
        ..countRun(orbs: 3)
        ..recordScore(0, 100)
        ..record(0, 0)
        ..record(3, 1);

      expect(profile.clearedCount, 1);
      expect(profile.runsPlayed, 1);
    });
  });

  group('What a rank changes in a run', () {
    test('nothing bought leaves the stock game alone', () {
      final stock = _game(UpgradeLoadout.none);

      expect(stock.world.slotCount, GameConfig.neonDash.bonus.slotCount);
      expect(stock.world.shieldCharges, 0);
    });

    test('the fourth slot is a fourth slot', () {
      final upgraded = _game(
        const UpgradeLoadout(<Upgrade, int>{Upgrade.extraSlot: 1}),
      );

      expect(upgraded.world.slotCount, GameConfig.neonDash.bonus.slotCount + 1);

      final world = upgraded.world as World;
      expect(upgraded.world.slotCount, BonusKind.values.length);
      for (final kind in BonusKind.values) {
        expect(world.storeBonus(kind), isTrue, reason: kind.name);
      }
    });

    test('a reinforced hull starts every run charged, one per rank', () {
      final one = _game(
        const UpgradeLoadout(<Upgrade, int>{Upgrade.startingShield: 1}),
      );
      final two = _game(
        const UpgradeLoadout(<Upgrade, int>{Upgrade.startingShield: 2}),
      );

      expect(one.world.shieldCharges, 1);
      expect(two.world.shieldCharges, 2);

      two.restart();
      expect(two.world.shieldCharges, 2,
          reason: 'every run, not the first one only');
    });

    test('an overcharged core lengthens a timed power-up by rank', () {
      final stock = _game(UpgradeLoadout.none);
      final rankOne =
          _game(const UpgradeLoadout(<Upgrade, int>{Upgrade.potency: 1}));
      final rankThree =
          _game(const UpgradeLoadout(<Upgrade, int>{Upgrade.potency: 3}));

      for (final game in <Game>[stock, rankOne, rankThree]) {
        (game.world as World).beginBonus(BonusKind.chrono);
      }

      final base = stock.world.remainingFor(BonusKind.chrono);
      expect(rankOne.world.remainingFor(BonusKind.chrono),
          closeTo(base * 1.15, 1e-6));
      expect(rankThree.world.remainingFor(BonusKind.chrono),
          closeTo(base * 1.45, 1e-6));
    });

    test('an overcharged core widens the magnet by rank', () {
      final stock = _game(UpgradeLoadout.none);
      final rankThree =
          _game(const UpgradeLoadout(<Upgrade, int>{Upgrade.potency: 3}));

      expect(
        rankThree.config.bonus.magnetRadius,
        closeTo(stock.config.bonus.magnetRadius * 1.66, 1e-6),
      );
    });

    test('a scavenger array makes power-ups commoner', () {
      final stock = _game(UpgradeLoadout.none);
      final lucky =
          _game(const UpgradeLoadout(<Upgrade, int>{Upgrade.fortune: 2}));

      expect(
        lucky.config.bonus.pickupChance,
        closeTo(stock.config.bonus.pickupChance * 1.5, 1e-6),
      );
    });

    test('a salvage rig pays more for the same run', () {
      int paid(UpgradeLoadout loadout) {
        final game = _game(loadout);
        (game.world as World)
          ..orbsCollected = 20
          ..checkpointsPassed = 3;

        return RunSummary.of(
          game.world,
          LevelCatalogue.byIndex(3),
          loadout: loadout,
        ).shards;
      }

      const rigged = UpgradeLoadout(<Upgrade, int>{Upgrade.salvage: 3});

      expect(paid(UpgradeLoadout.none), greaterThan(0));
      expect(paid(rigged), greaterThan(paid(UpgradeLoadout.none)));
    });

    test('a charge upgrade does not touch a charge power-up', () {
      final upgraded =
          _game(const UpgradeLoadout(<Upgrade, int>{Upgrade.potency: 3}));

      (upgraded.world as World).beginBonus(BonusKind.shield);

      expect(upgraded.world.remainingFor(BonusKind.shield), 0.0);
      expect(upgraded.world.shieldCharges, 1);
    });

    test('a profile hands the game exactly what was bought', () {
      final profile = Progression(shards: 100000)
        ..buy(Upgrade.extraSlot)
        ..buy(Upgrade.startingShield);

      final loadout = profile.loadout;

      expect(loadout.extraSlots, 1);
      expect(loadout.startingShields, 1);
      expect(loadout.bonusDurationScale, 1.0, reason: 'potency unbought');
      expect(loadout.magnetRadiusScale, 1.0);
      expect(loadout.payoutScale, 1.0);
      expect(loadout.totalRanks, 2);
    });
  });
}

Game _game(UpgradeLoadout loadout) => Game(
      level: LevelCatalogue.byIndex(3),
      loadout: loadout,
    )..resizeToScreenAspect(_phoneAspect);
