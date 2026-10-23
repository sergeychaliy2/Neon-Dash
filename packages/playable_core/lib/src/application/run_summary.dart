import '../domain/craft_skin.dart';
import '../domain/game_phase.dart';
import '../domain/level.dart';
import '../domain/upgrade.dart';
import '../domain/run_mode.dart';
import 'world.dart';

class RunSummary {
  const RunSummary({
    required this.levelIndex,
    required this.mode,
    required this.finished,
    required this.score,
    required this.orbs,
    required this.nearMisses,
    required this.hits,
    required this.progress,
    required this.checkpointsPassed,
    required this.continuesUsed,
    required this.bonusesSpent,
    required this.stars,
    required this.shards,
  });

  factory RunSummary.of(
    WorldView world,
    LevelDefinition level, {
    RunMode mode = RunMode.fixed,
    CraftSkin skin = CraftSkin.standard,
    UpgradeLoadout loadout = UpgradeLoadout.none,
  }) {
    final finished = world.phase == GamePhase.finished;
    final stars = level.stars.evaluate(
      finished: finished,
      orbs: world.orbsCollected,
      hits: world.hitsTaken,
    );

    return RunSummary(
      levelIndex: level.index,
      mode: mode,
      finished: finished,
      score: world.score.floor(),
      orbs: world.orbsCollected,
      nearMisses: world.nearMissCount,
      hits: world.hitsTaken,
      progress: world.routeProgress,
      checkpointsPassed: world.checkpointsPassed,
      continuesUsed: world.continuesUsed,
      bonusesSpent: world.bonusesSpent,
      stars: stars,
      shards: _shardsFor(
        finished: finished,
        orbs: world.orbsCollected,
        checkpoints: world.checkpointsPassed,
        payoutScale:
            mode.shardScale * skin.shardScale * loadout.payoutScale,
      ),
    );
  }

  static int priceOfContinue(int continuesUsed) {
    final steps = continuesUsed < 0 ? 0 : continuesUsed;
    return steps >= _maxPriceDoublings
        ? _basePrice << _maxPriceDoublings
        : _basePrice << steps;
  }

  static const int _basePrice = 30;

  static const int _maxPriceDoublings = 8;

  static const int _finishBonus = 25;

  static const int _checkpointBonus = 4;

  static int _shardsFor({
    required bool finished,
    required int orbs,
    required int checkpoints,
    required double payoutScale,
  }) {
    final earned = finished
        ? orbs + _finishBonus
        : orbs + checkpoints * _checkpointBonus;
    return (earned * payoutScale).round();
  }

  final int levelIndex;

  final RunMode mode;

  final bool finished;

  final int score;
  final int orbs;
  final int nearMisses;

  final int hits;

  final double progress;

  final int checkpointsPassed;
  final int continuesUsed;

  final int bonusesSpent;

  final int stars;

  final int shards;

  int get continuePrice => priceOfContinue(continuesUsed);

  int get progressPercent => (progress * 100.0).round();
}
