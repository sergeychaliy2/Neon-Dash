import 'dart:convert';

import 'achievement.dart';
import 'craft_skin.dart';
import 'level.dart';
import 'level_catalogue.dart';
import 'run_mode.dart';
import 'upgrade.dart';

class Progression {
  Progression({
    Map<int, int>? starsByLevel,
    Map<int, int>? bestScoreByLevel,
    Map<int, int>? bestShiftingByLevel,
    Map<Upgrade, int>? upgradeRanks,
    Set<CraftSkin>? skins,
    CraftSkin selectedSkin = CraftSkin.standard,
    int shards = 0,
    int runsPlayed = 0,
    int orbsCollected = 0,
    int finishes = 0,
    int shiftingFinishes = 0,
    int perfectRuns = 0,
    int nearMisses = 0,
    int bonusesSpent = 0,
    int shardsEarned = 0,
    int continuesBought = 0,
  })  : _starsByLevel = <int, int>{...?starsByLevel},
        _bestScoreByLevel = <int, int>{...?bestScoreByLevel},
        _bestShiftingByLevel = <int, int>{...?bestShiftingByLevel},
        _upgradeRanks = <Upgrade, int>{...?upgradeRanks},
        _skins = <CraftSkin>{CraftSkin.standard, ...?skins},
        // ignore: prefer_initializing_formals
        _selectedSkin = selectedSkin,
        _shards = shards < 0 ? 0 : shards,
        _runsPlayed = runsPlayed < 0 ? 0 : runsPlayed,
        _orbsCollected = orbsCollected < 0 ? 0 : orbsCollected,
        _finishes = finishes < 0 ? 0 : finishes,
        _shiftingFinishes = shiftingFinishes < 0 ? 0 : shiftingFinishes,
        _perfectRuns = perfectRuns < 0 ? 0 : perfectRuns,
        _nearMisses = nearMisses < 0 ? 0 : nearMisses,
        _bonusesSpent = bonusesSpent < 0 ? 0 : bonusesSpent,
        _shardsEarned = shardsEarned < 0 ? 0 : shardsEarned,
        _continuesBought = continuesBought < 0 ? 0 : continuesBought;

  factory Progression.fromJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) return Progression();

      return Progression(
        starsByLevel: _readCounts(decoded['stars'], _clampStars),
        bestScoreByLevel: _readCounts(decoded['scores'], _clampPositive),
        bestShiftingByLevel:
            _readCounts(decoded['scoresShifting'], _clampPositive),
        upgradeRanks: _readUpgradeRanks(decoded['upgrades']),
        skins: _readSkins(decoded['skins']),
        selectedSkin: _readSkin(decoded['skin']),
        shards: _readInt(decoded['shards']),
        runsPlayed: _readInt(decoded['runs']),
        orbsCollected: _readInt(decoded['orbs']),
        finishes: _readInt(decoded['finishes']),
        shiftingFinishes: _readInt(decoded['shiftingFinishes']),
        perfectRuns: _readInt(decoded['perfect']),
        nearMisses: _readInt(decoded['nearMisses']),
        bonusesSpent: _readInt(decoded['bonusesSpent']),
        shardsEarned: _readInt(decoded['shardsEarned']),
        continuesBought: _readInt(decoded['continues']),
      );
    } on Object {
      return Progression();
    }
  }

  static const int _formatVersion = 2;

  final Map<int, int> _starsByLevel;
  final Map<int, int> _bestScoreByLevel;
  final Map<int, int> _bestShiftingByLevel;
  final Map<Upgrade, int> _upgradeRanks;
  final Set<CraftSkin> _skins;
  CraftSkin _selectedSkin;
  int _shards;
  int _runsPlayed;
  int _orbsCollected;
  int _finishes;
  int _shiftingFinishes;
  int _perfectRuns;
  int _nearMisses;
  int _bonusesSpent;
  int _shardsEarned;
  int _continuesBought;

  int get shards => _shards;

  int get runsPlayed => _runsPlayed;

  int get orbsCollected => _orbsCollected;

  int metric(AchievementMetric metric) => switch (metric) {
        AchievementMetric.runs => _runsPlayed,
        AchievementMetric.finishes => _finishes,
        AchievementMetric.shiftingFinishes => _shiftingFinishes,
        AchievementMetric.perfectRuns => _perfectRuns,
        AchievementMetric.levelsCleared => clearedCount,
        AchievementMetric.stars => totalStars,
        AchievementMetric.orbs => _orbsCollected,
        AchievementMetric.nearMisses => _nearMisses,
        AchievementMetric.bonusesSpent => _bonusesSpent,
        AchievementMetric.shardsEarned => _shardsEarned,
        AchievementMetric.continuesBought => _continuesBought,
        AchievementMetric.bestScore => bestScore,
        AchievementMetric.hullsOwned => _skins.length,
        AchievementMetric.upgradesOwned => upgradeRanks,
      };

  bool hasEarned(Achievement achievement) =>
      metric(achievement.metric) >= achievement.target;

  int progressOf(Achievement achievement) {
    final value = metric(achievement.metric);
    return value > achievement.target ? achievement.target : value;
  }

  Set<Achievement> get earnedAchievements => <Achievement>{
        for (final achievement in Achievement.values)
          if (hasEarned(achievement)) achievement,
      };

  int get earnedAchievementCount {
    var earned = 0;
    for (final achievement in Achievement.values) {
      if (hasEarned(achievement)) earned++;
    }
    return earned;
  }

  UpgradeLoadout get loadout => UpgradeLoadout(_upgradeRanks);

  int rankOf(Upgrade upgrade) => loadout.rankOf(upgrade);

  bool isMaxed(Upgrade upgrade) => rankOf(upgrade) >= upgrade.maxRank;

  int priceOf(Upgrade upgrade) => upgrade.priceFrom(rankOf(upgrade));

  int get upgradeRanks => loadout.totalRanks;

  CraftSkin get selectedSkin => _selectedSkin;

  Set<CraftSkin> get skins => Set<CraftSkin>.unmodifiable(_skins);

  bool ownsSkin(CraftSkin skin) => _skins.contains(skin);

  bool canAffordSkin(CraftSkin skin) =>
      !ownsSkin(skin) && _shards >= skin.price;

  bool buySkin(CraftSkin skin) {
    if (!canAffordSkin(skin)) return false;
    _shards -= skin.price;
    _skins.add(skin);
    _selectedSkin = skin;
    return true;
  }

  bool selectSkin(CraftSkin skin) {
    if (!ownsSkin(skin)) return false;
    _selectedSkin = skin;
    return true;
  }

  bool owns(Upgrade upgrade) => rankOf(upgrade) > 0;

  bool canAfford(Upgrade upgrade) =>
      !isMaxed(upgrade) && _shards >= priceOf(upgrade);

  bool buy(Upgrade upgrade) {
    if (!canAfford(upgrade)) return false;
    _shards -= priceOf(upgrade);
    _upgradeRanks[upgrade] = rankOf(upgrade) + 1;
    return true;
  }

  int starsFor(int levelIndex) => _starsByLevel[levelIndex] ?? 0;

  int bestScoreFor(int levelIndex, {RunMode mode = RunMode.fixed}) =>
      _scoresFor(mode)[levelIndex] ?? 0;

  Map<int, int> _scoresFor(RunMode mode) =>
      mode.isRandomised ? _bestShiftingByLevel : _bestScoreByLevel;

  bool isShiftingUnlocked(int levelIndex) => isCleared(levelIndex);

  int get bestScore {
    var best = 0;
    for (final scores in <Map<int, int>>[
      _bestScoreByLevel,
      _bestShiftingByLevel,
    ]) {
      for (final score in scores.values) {
        if (score > best) best = score;
      }
    }
    return best;
  }

  int get clearedCount {
    var cleared = 0;
    for (final stars in _starsByLevel.values) {
      if (stars > 0) cleared++;
    }
    return cleared;
  }

  bool isCleared(int levelIndex) => starsFor(levelIndex) > 0;

  int get totalStars {
    var total = 0;
    for (final stars in _starsByLevel.values) {
      total += stars;
    }
    return total;
  }

  int get unlockedCount {
    var open = 0;
    for (final level in LevelCatalogue.levels) {
      if (isUnlocked(level)) open++;
    }
    return open;
  }

  bool isUnlocked(LevelDefinition level) => switch (level.unlock) {
        AlwaysOpen() => true,
        AfterLevel(:final levelIndex) => isCleared(levelIndex),
        StarsRequired(:final stars) => totalStars >= stars,
      };

  int starsStillNeeded(LevelDefinition level) => switch (level.unlock) {
        AlwaysOpen() || AfterLevel() => 0,
        StarsRequired(:final stars) =>
          totalStars >= stars ? 0 : stars - totalStars,
      };

  bool record(int levelIndex, int stars) {
    final earned = _clampStars(stars);
    if (earned <= starsFor(levelIndex)) return false;
    _starsByLevel[levelIndex] = earned;
    return true;
  }

  bool recordScore(
    int levelIndex,
    int score, {
    RunMode mode = RunMode.fixed,
  }) {
    final earned = _clampPositive(score);
    if (earned <= bestScoreFor(levelIndex, mode: mode)) return false;
    _scoresFor(mode)[levelIndex] = earned;
    return true;
  }

  void countRun({
    required int orbs,
    int nearMisses = 0,
    int bonusesSpent = 0,
    int continuesBought = 0,
    int stars = 0,
    bool finished = false,
    bool shifting = false,
  }) {
    _runsPlayed++;
    if (orbs > 0) _orbsCollected += orbs;
    if (nearMisses > 0) _nearMisses += nearMisses;
    if (bonusesSpent > 0) _bonusesSpent += bonusesSpent;
    if (continuesBought > 0) _continuesBought += continuesBought;

    if (!finished) return;
    _finishes++;
    if (shifting) _shiftingFinishes++;
    if (stars >= StarRules.maxPerLevel) _perfectRuns++;
  }

  void addShards(int amount) {
    if (amount <= 0) return;
    _shards += amount;
    _shardsEarned += amount;
  }

  bool spendShards(int amount) {
    if (amount <= 0 || amount > _shards) return false;
    _shards -= amount;
    return true;
  }

  String toJson() => jsonEncode(<String, dynamic>{
        'version': _formatVersion,
        'shards': _shards,
        'runs': _runsPlayed,
        'orbs': _orbsCollected,
        'finishes': _finishes,
        'shiftingFinishes': _shiftingFinishes,
        'perfect': _perfectRuns,
        'nearMisses': _nearMisses,
        'bonusesSpent': _bonusesSpent,
        'shardsEarned': _shardsEarned,
        'continues': _continuesBought,
        'stars': <String, int>{
          for (final entry in _starsByLevel.entries)
            '${entry.key}': entry.value,
        },
        'scores': <String, int>{
          for (final entry in _bestScoreByLevel.entries)
            '${entry.key}': entry.value,
        },
        'scoresShifting': <String, int>{
          for (final entry in _bestShiftingByLevel.entries)
            '${entry.key}': entry.value,
        },
        'upgrades': <String, int>{
          for (final entry in _upgradeRanks.entries)
            entry.key.name: entry.value,
        },
        'skins': <String>[
          for (final skin in _skins) skin.name,
        ],
        'skin': _selectedSkin.name,
      });

  static int _clampStars(int stars) {
    if (stars < 0) return 0;
    return stars > StarRules.maxPerLevel ? StarRules.maxPerLevel : stars;
  }

  static int _clampPositive(int value) => value < 0 ? 0 : value;

  static int _readInt(Object? raw) => raw is int && raw > 0 ? raw : 0;

  static Map<int, int> _readCounts(Object? raw, int Function(int) clamp) {
    final counts = <int, int>{};
    if (raw is! Map) return counts;

    for (final entry in raw.entries) {
      final index = int.tryParse('${entry.key}');
      final value = entry.value;
      if (index == null || index < 0 || value is! int) continue;
      counts[index] = clamp(value);
    }
    return counts;
  }

  static Set<CraftSkin> _readSkins(Object? raw) {
    final owned = <CraftSkin>{};
    if (raw is! List) return owned;

    for (final entry in raw) {
      for (final skin in CraftSkin.values) {
        if (skin.name == entry) owned.add(skin);
      }
    }
    return owned;
  }

  static CraftSkin _readSkin(Object? raw) {
    for (final skin in CraftSkin.values) {
      if (skin.name == raw) return skin;
    }
    return CraftSkin.standard;
  }

  static Map<Upgrade, int> _readUpgradeRanks(Object? raw) {
    final owned = <Upgrade, int>{};

    Upgrade? named(Object? name) {
      for (final upgrade in Upgrade.values) {
        if (upgrade.name == name) return upgrade;
      }
      return null;
    }

    if (raw is List) {
      for (final entry in raw) {
        final upgrade = named(entry);
        if (upgrade != null) owned[upgrade] = 1;
      }
      return owned;
    }

    if (raw is! Map) return owned;
    for (final entry in raw.entries) {
      final upgrade = named(entry.key);
      final rank = entry.value;
      if (upgrade == null || rank is! int || rank <= 0) continue;
      owned[upgrade] = rank > upgrade.maxRank ? upgrade.maxRank : rank;
    }
    return owned;
  }
}
