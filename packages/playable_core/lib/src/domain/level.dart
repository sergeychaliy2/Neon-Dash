import '../config/game_config.dart';
import 'bonus_kind.dart';
import 'package:playable_kit/playable_kit.dart';

import 'level_theme.dart';
import 'portal_kind.dart';

sealed class LevelUnlock {
  const LevelUnlock();
}

class AlwaysOpen extends LevelUnlock {
  const AlwaysOpen();
}

class AfterLevel extends LevelUnlock {
  const AfterLevel(this.levelIndex);

  final int levelIndex;
}

class StarsRequired extends LevelUnlock {
  const StarsRequired(this.stars);

  final int stars;
}

class StarRules {
  const StarRules({required this.orbTarget});

  final int orbTarget;

  int evaluate({
    required bool finished,
    required int orbs,
    required int hits,
  }) {
    if (!finished) return 0;

    var stars = 1;
    if (orbs >= orbTarget) stars++;
    if (hits == 0) stars++;
    return stars;
  }

  static const int maxPerLevel = 3;
}

class LevelDefinition {
  const LevelDefinition({
    required this.index,
    required this.name,
    required this.tagline,
    required this.unlock,
    required this.theme,
    required this.music,
    required this.patternWeights,
    required this.wave,
    required this.bonuses,
    required this.portals,
    required this.difficulty,
    required this.routeSeconds,
    required this.routeDensity,
    required this.stars,
  });

  final int index;

  final String name;
  final String tagline;
  final LevelUnlock unlock;
  final LevelTheme theme;
  final MusicVoice music;

  final Map<WavePattern, double> patternWeights;

  final WaveConfig wave;

  Set<WavePattern> get patterns => patternWeights.keys.toSet();

  WavePattern get signaturePattern {
    var best = WavePattern.sides;
    var bestWeight = -1.0;
    for (final entry in patternWeights.entries) {
      if (entry.value <= bestWeight) continue;
      best = entry.key;
      bestWeight = entry.value;
    }
    return best;
  }

  final Set<BonusKind> bonuses;

  final DifficultyConfig difficulty;

  final double routeSeconds;

  final double routeDensity;

  RouteConfig get route {
    final length = difficulty.distanceOver(routeSeconds);

    return RouteConfig(
      firstStageLength: length,
      stageGrowth: 1.0,
      maxStageLength: length,
      checkpointCount: 4,
      minSegmentLength: 180.0,
      maxSegmentLength: 320.0,
      openingLength: 260.0,
      baseDenseChance: routeDensity,
      denseChancePerStage: 0.0,
      maxDenseChance: 0.6,
      calmChance: 0.3,
    );
  }
  final Set<PortalKind> portals;

  final StarRules stars;

  int get stageNumber => index + 1;
}
