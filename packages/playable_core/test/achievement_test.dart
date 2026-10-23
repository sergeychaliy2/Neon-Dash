import 'package:playable_core/playable_core.dart';
import 'package:test/test.dart';

void main() {
  group('The list itself', () {
    test('there are plenty, and each says what it wants', () {
      expect(Achievement.values.length, greaterThanOrEqualTo(24));

      for (final achievement in Achievement.values) {
        expect(achievement.title, isNotEmpty, reason: achievement.name);
        expect(achievement.detail, isNotEmpty, reason: achievement.name);
        expect(achievement.target, greaterThan(0), reason: achievement.name);
      }
    });

    test('no two share a title', () {
      final titles = <String>{
        for (final achievement in Achievement.values) achievement.title,
      };

      expect(titles, hasLength(Achievement.values.length));
    });

    test('every metric is watched by something', () {
      final watched = <AchievementMetric>{
        for (final achievement in Achievement.values) achievement.metric,
      };

      expect(watched, hasLength(AchievementMetric.values.length));
    });

    test('a target is reachable from what the game actually holds', () {
      expect(
        Achievement.everyStar.target,
        LevelCatalogue.count * StarRules.maxPerLevel,
        reason: 'all the stars means all the stars',
      );
      expect(Achievement.terminus.target, LevelCatalogue.count);
      expect(Achievement.fullHangar.target, CraftSkin.values.length);
      expect(Achievement.wellEquipped.target, Upgrade.totalRanks);
    });

    test('tiers of the same metric climb', () {
      final byMetric = <AchievementMetric, List<int>>{};
      for (final achievement in Achievement.values) {
        byMetric.putIfAbsent(achievement.metric, () => <int>[])
            .add(achievement.target);
      }

      for (final entry in byMetric.entries) {
        final sorted = List<int>.of(entry.value)..sort();
        expect(entry.value, sorted, reason: '${entry.key.name} is out of order');
        expect(entry.value.toSet(), hasLength(entry.value.length),
            reason: '${entry.key.name} has two tiers at the same target');
      }
    });
  });

  group('Earning them', () {
    test('a fresh profile has earned nothing', () {
      final profile = Progression();

      expect(profile.earnedAchievementCount, 0);
      expect(profile.earnedAchievements, isEmpty);
      for (final achievement in Achievement.values) {
        expect(profile.hasEarned(achievement), isFalse,
            reason: achievement.name);
      }
    });

    test('one run earns the first one', () {
      final profile = Progression()..countRun(orbs: 0);

      expect(profile.hasEarned(Achievement.firstFlight), isTrue);
      expect(profile.hasEarned(Achievement.gettingTheHang), isFalse);
    });

    test('progress is reported, and capped at the target', () {
      final profile = Progression();
      for (var i = 0; i < 40; i++) {
        profile.countRun(orbs: 0);
      }

      expect(profile.progressOf(Achievement.gettingTheHang), 25);
      expect(profile.progressOf(Achievement.regular), 40);
    });

    test('a finish counts as a finish and as a run', () {
      final profile = Progression()
        ..countRun(orbs: 5, finished: true, stars: 2);

      expect(profile.metric(AchievementMetric.runs), 1);
      expect(profile.metric(AchievementMetric.finishes), 1);
      expect(profile.hasEarned(Achievement.madeIt), isTrue);
      expect(profile.hasEarned(Achievement.untouched), isFalse,
          reason: 'two stars is not perfect');
    });

    test('a three-star finish is a perfect run', () {
      final profile = Progression()
        ..countRun(orbs: 5, finished: true, stars: StarRules.maxPerLevel);

      expect(profile.hasEarned(Achievement.untouched), isTrue);
    });

    test('a three-star run that did not finish is not a perfect run', () {
      final profile = Progression()..countRun(orbs: 0, stars: 3);

      expect(profile.metric(AchievementMetric.perfectRuns), 0);
    });

    test('a shifting finish counts twice over', () {
      final profile = Progression()
        ..countRun(orbs: 0, finished: true, shifting: true);

      expect(profile.metric(AchievementMetric.finishes), 1);
      expect(profile.metric(AchievementMetric.shiftingFinishes), 1);
      expect(profile.hasEarned(Achievement.noRehearsal), isTrue);
    });

    test('spending shards does not undo having earned them', () {
      final profile = Progression()..addShards(6000);
      expect(profile.hasEarned(Achievement.wealthy), isTrue);

      profile.spendShards(5900);

      expect(profile.shards, 100);
      expect(profile.hasEarned(Achievement.wealthy), isTrue,
          reason: 'the achievement is about earning, not about holding');
    });

    test('owning hulls and upgrades is noticed', () {
      final profile = Progression(shards: 20000);
      expect(profile.hasEarned(Achievement.secondOpinion), isFalse);

      profile
        ..buySkin(CraftSkin.lance)
        ..buySkin(CraftSkin.kite);

      expect(profile.hasEarned(Achievement.secondOpinion), isTrue,
          reason: 'two bought plus the standard one');

      for (final upgrade in Upgrade.values) {
        for (var rank = 0; rank < upgrade.maxRank; rank++) {
          expect(profile.buy(upgrade), isTrue, reason: upgrade.name);
        }
      }
      expect(profile.metric(AchievementMetric.upgradesOwned),
          Upgrade.totalRanks);
      expect(profile.hasEarned(Achievement.wellEquipped), isTrue);
    });

    test('everything the player did survives a round trip', () {
      final profile = Progression()
        ..countRun(
          orbs: 30,
          nearMisses: 12,
          bonusesSpent: 4,
          continuesBought: 1,
          stars: 3,
          finished: true,
          shifting: true,
        )
        ..addShards(700);

      final restored = Progression.fromJson(profile.toJson());

      for (final metric in AchievementMetric.values) {
        expect(restored.metric(metric), profile.metric(metric),
            reason: metric.name);
      }
      expect(restored.earnedAchievements, profile.earnedAchievements);
    });

    test('a save from before achievements existed starts them at zero', () {
      const legacy = '{"version":2,"shards":40,"stars":{"0":3},"runs":9}';

      final restored = Progression.fromJson(legacy);

      expect(restored.metric(AchievementMetric.runs), 9);
      expect(restored.metric(AchievementMetric.finishes), 0);
      expect(restored.hasEarned(Achievement.firstStars), isTrue,
          reason: 'derived from the stars that are there');
    });

    test('they are derived, so a new one credits what already happened', () {
      final profile = Progression();
      for (var i = 0; i < 300; i++) {
        profile.countRun(orbs: 10, nearMisses: 5);
      }

      expect(profile.hasEarned(Achievement.recklessness), isTrue);
      expect(profile.hasEarned(Achievement.vault), isTrue);
      expect(profile.hasEarned(Achievement.regular), isTrue);
    });
  });
}
