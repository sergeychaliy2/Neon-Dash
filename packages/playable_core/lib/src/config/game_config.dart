library;

import '../domain/bonus_kind.dart';
import '../domain/craft_skin.dart';
import '../domain/portal_kind.dart';
import '../domain/upgrade.dart';

class ViewportConfig {
  const ViewportConfig({
    required this.worldHeight,
    required this.minFieldAspect,
    required this.maxFieldAspect,
  });

  final double worldHeight;

  final double minFieldAspect;

  final double maxFieldAspect;

  double widthForScreenAspect(double screenAspect) {
    if (screenAspect < minFieldAspect) return worldHeight * minFieldAspect;
    if (screenAspect > maxFieldAspect) return worldHeight * maxFieldAspect;
    return worldHeight * screenAspect;
  }
}

class PlayerConfig {
  const PlayerConfig({
    required this.lineY,
    required this.radius,
    required this.speedInWidths,
    required this.followRate,
  });

  final double lineY;

  final double radius;

  final double speedInWidths;

  final double followRate;

  PlayerConfig withHull(CraftSkin skin) => PlayerConfig(
        lineY: lineY,
        radius: radius * skin.radiusScale,
        speedInWidths: speedInWidths * skin.speedScale,
        followRate: followRate * skin.gripScale,
      );
}

class DifficultyConfig {
  const DifficultyConfig({
    required this.startScrollSpeed,
    required this.maxScrollSpeed,
    required this.speedRampSeconds,
    required this.startSpawnInterval,
    required this.minSpawnInterval,
    required this.spawnRampSeconds,
    required this.startGapFraction,
    required this.minGapFraction,
    required this.gapRampSeconds,
  });

  final double startScrollSpeed;

  final double maxScrollSpeed;
  final double speedRampSeconds;

  final double startSpawnInterval;
  final double minSpawnInterval;
  final double spawnRampSeconds;

  final double startGapFraction;
  final double minGapFraction;
  final double gapRampSeconds;

  double distanceOver(double seconds) {
    if (seconds <= 0.0) return 0.0;
    if (speedRampSeconds <= 0.0) return maxScrollSpeed * seconds;

    if (seconds <= speedRampSeconds) {
      final reached = startScrollSpeed +
          (maxScrollSpeed - startScrollSpeed) * (seconds / speedRampSeconds);
      return (startScrollSpeed + reached) * 0.5 * seconds;
    }

    final whileRamping =
        (startScrollSpeed + maxScrollSpeed) * 0.5 * speedRampSeconds;
    return whileRamping + maxScrollSpeed * (seconds - speedRampSeconds);
  }
}

class ScoreConfig {
  const ScoreConfig({
    required this.perWorldUnit,
    required this.nearMiss,
    required this.orb,
    required this.nearMissMargin,
  });

  final double perWorldUnit;

  final double nearMiss;

  final double orb;

  final double nearMissMargin;
}

class PoolConfig {
  const PoolConfig({
    required this.maxObstacles,
    required this.maxOrbs,
    required this.maxParticles,
    required this.maxPickups,
    required this.maxPortals,
  });

  final int maxObstacles;
  final int maxOrbs;
  final int maxParticles;
  final int maxPickups;

  final int maxPortals;
}

class BonusConfig {
  const BonusConfig({
    required this.slotCount,
    required this.pickupRadius,
    required this.pickupChance,
    required this.magnetRadius,
    required this.magnetPullPerSecond,
    required this.immunitySeconds,
    this.available = const <BonusKind>{},
    this.startingShields = 0,
    this.durationScale = 1.0,
  });

  final Set<BonusKind> available;

  BonusConfig withAvailable(Set<BonusKind> kinds) => BonusConfig(
        slotCount: slotCount,
        pickupRadius: pickupRadius,
        pickupChance: pickupChance,
        magnetRadius: magnetRadius,
        magnetPullPerSecond: magnetPullPerSecond,
        immunitySeconds: immunitySeconds,
        available: kinds,
        startingShields: startingShields,
        durationScale: durationScale,
      );

  BonusConfig withLoadout(UpgradeLoadout loadout) => BonusConfig(
        slotCount: slotCount + loadout.extraSlots,
        pickupRadius: pickupRadius,
        pickupChance: pickupChance * loadout.pickupChanceScale,
        magnetRadius: magnetRadius * loadout.magnetRadiusScale,
        magnetPullPerSecond: magnetPullPerSecond,
        immunitySeconds: immunitySeconds,
        available: available,
        startingShields: startingShields + loadout.startingShields,
        durationScale: durationScale * loadout.bonusDurationScale,
      );

  final int slotCount;

  final double pickupRadius;

  final double pickupChance;

  final double magnetRadius;

  final double magnetPullPerSecond;

  final double immunitySeconds;

  final int startingShields;

  final double durationScale;
}

class SimulationConfig {
  const SimulationConfig({
    required this.fixedStep,
    required this.maxStepsPerFrame,
  });

  final double fixedStep;

  final int maxStepsPerFrame;
}

const int kBeatsPerMinute = 140;

const double kBeatSeconds = 60.0 / kBeatsPerMinute;

enum HazardClass {
  calm(spawnIntervalScale: 1.45, gapScale: 1.22, orbChanceScale: 1.7),

  moderate(spawnIntervalScale: 1.0, gapScale: 1.0, orbChanceScale: 1.0),

  dense(spawnIntervalScale: 0.78, gapScale: 0.84, orbChanceScale: 0.45);

  const HazardClass({
    required this.spawnIntervalScale,
    required this.gapScale,
    required this.orbChanceScale,
  });

  final double spawnIntervalScale;

  final double gapScale;

  final double orbChanceScale;
}

class RouteConfig {
  const RouteConfig({
    required this.firstStageLength,
    required this.stageGrowth,
    required this.maxStageLength,
    required this.checkpointCount,
    required this.minSegmentLength,
    required this.maxSegmentLength,
    required this.openingLength,
    required this.baseDenseChance,
    required this.denseChancePerStage,
    required this.maxDenseChance,
    required this.calmChance,
    this.finishRunIn = 95.0,
  });

  final double firstStageLength;

  final double stageGrowth;
  final double maxStageLength;

  final int checkpointCount;
  final double minSegmentLength;
  final double maxSegmentLength;

  final double openingLength;

  final double baseDenseChance;
  final double denseChancePerStage;
  final double maxDenseChance;
  final double calmChance;

  final double finishRunIn;

  double lengthForStage(int stage) {
    var length = firstStageLength;
    for (var i = 1; i < stage; i++) {
      length *= stageGrowth;
      if (length >= maxStageLength) return maxStageLength;
    }
    return length;
  }

  double denseChanceForStage(int stage) {
    final chance = baseDenseChance + denseChancePerStage * (stage - 1);
    return chance > maxDenseChance ? maxDenseChance : chance;
  }

  static const RouteConfig neonDash = RouteConfig(
    firstStageLength: 2200.0,
    stageGrowth: 1.15,
    maxStageLength: 6000.0,
    checkpointCount: 4,
    minSegmentLength: 180.0,
    maxSegmentLength: 320.0,
    openingLength: 260.0,
    baseDenseChance: 0.22,
    denseChancePerStage: 0.04,
    maxDenseChance: 0.5,
    calmChance: 0.3,
  );
}

enum WavePattern {
  sides(unlocksAtSeconds: 0.0),

  island(unlocksAtSeconds: 10.0),

  comb(unlocksAtSeconds: 16.0),

  spikeRow(unlocksAtSeconds: 26.0),

  mines(unlocksAtSeconds: 30.0),

  gate(unlocksAtSeconds: 32.0),

  weave(unlocksAtSeconds: 34.0),

  corridor(unlocksAtSeconds: 0.0),

  funnel(unlocksAtSeconds: 12.0),

  zipper(unlocksAtSeconds: 20.0),

  staircase(unlocksAtSeconds: 24.0),

  ramps(unlocksAtSeconds: 6.0),

  sawRow(unlocksAtSeconds: 28.0);

  const WavePattern({required this.unlocksAtSeconds});

  final double unlocksAtSeconds;
}

class WaveConfig {
  const WaveConfig({
    required this.boxHalfHeight,
    required this.pylonHalfHeight,
    required this.spikeHalfWidth,
    required this.spikeHalfHeight,
    required this.mineRadius,
    required this.minesPerWave,
    required this.combSlots,
    required this.driftUnlocksAtSeconds,
    required this.driftAmplitudeFraction,
    required this.driftRateHz,
    required this.gapMargin,
    required this.gateSwingFraction,
    required this.gateRateHz,
    required this.weaveSafetyFactor,
    required this.weaveMinSpacing,
    this.beatSeconds = kBeatSeconds,
    this.patternWeights = const <WavePattern, double>{},
    this.corridorWidthFraction = 0.34,
    this.corridorDepth = 26.0,
    this.funnelLayers = 3,
    this.funnelLayerSpacing = 16.0,
    this.zipperTeeth = 4,
    this.zipperToothFraction = 0.58,
    this.reactionSeconds = 0.24,
    this.minRowSeconds = 0.40,
    this.minRowGap = 20.0,
    this.staircaseSteps = 4,
    this.staircaseTravelFraction = 0.82,
    this.sawRadius = 2.6,
    this.sawsPerWave = 3,
  });

  final double beatSeconds;

  final double sawRadius;
  final int sawsPerWave;

  final int staircaseSteps;
  final double staircaseTravelFraction;

  final Map<WavePattern, double> patternWeights;

  final double corridorWidthFraction;

  final double corridorDepth;

  final int funnelLayers;
  final double funnelLayerSpacing;

  final int zipperTeeth;
  final double zipperToothFraction;

  WaveConfig copyWith({
    double? beatSeconds,
    double? boxHalfHeight,
    double? pylonHalfHeight,
    double? spikeHalfWidth,
    double? spikeHalfHeight,
    double? mineRadius,
    int? minesPerWave,
    int? combSlots,
    double? driftUnlocksAtSeconds,
    double? driftAmplitudeFraction,
    double? driftRateHz,
    double? gapMargin,
    double? gateSwingFraction,
    double? gateRateHz,
    double? weaveSafetyFactor,
    double? weaveMinSpacing,
    double? reactionSeconds,
    double? minRowSeconds,
    double? minRowGap,
    Map<WavePattern, double>? patternWeights,
    double? corridorWidthFraction,
    double? corridorDepth,
    int? funnelLayers,
    double? funnelLayerSpacing,
    int? zipperTeeth,
    double? zipperToothFraction,
    int? staircaseSteps,
    double? staircaseTravelFraction,
    double? sawRadius,
    int? sawsPerWave,
  }) =>
      WaveConfig(
        beatSeconds: beatSeconds ?? this.beatSeconds,
        boxHalfHeight: boxHalfHeight ?? this.boxHalfHeight,
        pylonHalfHeight: pylonHalfHeight ?? this.pylonHalfHeight,
        spikeHalfWidth: spikeHalfWidth ?? this.spikeHalfWidth,
        spikeHalfHeight: spikeHalfHeight ?? this.spikeHalfHeight,
        mineRadius: mineRadius ?? this.mineRadius,
        minesPerWave: minesPerWave ?? this.minesPerWave,
        combSlots: combSlots ?? this.combSlots,
        driftUnlocksAtSeconds:
            driftUnlocksAtSeconds ?? this.driftUnlocksAtSeconds,
        driftAmplitudeFraction:
            driftAmplitudeFraction ?? this.driftAmplitudeFraction,
        driftRateHz: driftRateHz ?? this.driftRateHz,
        gapMargin: gapMargin ?? this.gapMargin,
        gateSwingFraction: gateSwingFraction ?? this.gateSwingFraction,
        gateRateHz: gateRateHz ?? this.gateRateHz,
        weaveSafetyFactor: weaveSafetyFactor ?? this.weaveSafetyFactor,
        weaveMinSpacing: weaveMinSpacing ?? this.weaveMinSpacing,
        reactionSeconds: reactionSeconds ?? this.reactionSeconds,
        minRowSeconds: minRowSeconds ?? this.minRowSeconds,
        minRowGap: minRowGap ?? this.minRowGap,
        patternWeights: patternWeights ?? this.patternWeights,
        corridorWidthFraction:
            corridorWidthFraction ?? this.corridorWidthFraction,
        corridorDepth: corridorDepth ?? this.corridorDepth,
        funnelLayers: funnelLayers ?? this.funnelLayers,
        funnelLayerSpacing: funnelLayerSpacing ?? this.funnelLayerSpacing,
        zipperTeeth: zipperTeeth ?? this.zipperTeeth,
        zipperToothFraction: zipperToothFraction ?? this.zipperToothFraction,
        staircaseSteps: staircaseSteps ?? this.staircaseSteps,
        staircaseTravelFraction:
            staircaseTravelFraction ?? this.staircaseTravelFraction,
        sawRadius: sawRadius ?? this.sawRadius,
        sawsPerWave: sawsPerWave ?? this.sawsPerWave,
      );

  double weightOf(WavePattern pattern) {
    if (patternWeights.isEmpty) return 1.0;
    return patternWeights[pattern] ?? 0.0;
  }

  final double boxHalfHeight;

  final double pylonHalfHeight;

  final double spikeHalfWidth;
  final double spikeHalfHeight;
  final double mineRadius;
  final int minesPerWave;

  final int combSlots;

  final double driftUnlocksAtSeconds;

  final double driftAmplitudeFraction;

  final double driftRateHz;

  final double gapMargin;

  final double gateSwingFraction;

  final double gateRateHz;

  final double weaveSafetyFactor;

  final double weaveMinSpacing;

  final double reactionSeconds;

  final double minRowSeconds;

  final double minRowGap;
}

class PortalConfig {
  const PortalConfig({
    required this.intervalSeconds,
    required this.leadDistance,
    this.available = const <PortalKind>{},
  });

  final double intervalSeconds;

  final double leadDistance;

  final Set<PortalKind> available;

  PortalConfig withAvailable(Set<PortalKind> kinds) => PortalConfig(
        intervalSeconds: intervalSeconds,
        leadDistance: leadDistance,
        available: kinds,
      );

  double get worstScrollScale {
    var worst = 1.0;
    for (final kind in available) {
      if (kind.scrollScale > worst) worst = kind.scrollScale;
    }
    return worst;
  }

  static const PortalConfig neonDash = PortalConfig(
    intervalSeconds: 22.0,
    leadDistance: 140.0,
  );
}

class GameConfig {
  const GameConfig({
    required this.viewport,
    required this.player,
    required this.difficulty,
    required this.score,
    required this.pools,
    required this.simulation,
    required this.wave,
    required this.route,
    required this.bonus,
    required this.portal,
    required this.orbRadius,
    required this.orbChance,
    required this.particleLifetime,
    required this.particleSpeed,
    required this.trailCapacity,
    required this.trailSampleInterval,
  });

  final ViewportConfig viewport;
  final PlayerConfig player;
  final DifficultyConfig difficulty;
  final ScoreConfig score;
  final PoolConfig pools;
  final SimulationConfig simulation;
  final WaveConfig wave;
  final RouteConfig route;
  final BonusConfig bonus;
  final PortalConfig portal;

  final double orbRadius;

  final double orbChance;

  final double particleLifetime;

  final double particleSpeed;

  final int trailCapacity;

  final double trailSampleInterval;

  static const GameConfig neonDash = GameConfig(
    viewport: ViewportConfig(
      worldHeight: 100.0,
      minFieldAspect: 0.45,
      maxFieldAspect: 0.70,
    ),
    player: PlayerConfig(
      lineY: 82.0,
      radius: 2.1,
      speedInWidths: 1.75,
      followRate: 17.0,
    ),
    difficulty: DifficultyConfig(
      startScrollSpeed: 40.0,
      maxScrollSpeed: 88.0,
      speedRampSeconds: 70.0,
      startSpawnInterval: 0.95,
      minSpawnInterval: 0.34,
      spawnRampSeconds: 70.0,
      startGapFraction: 0.52,
      minGapFraction: 0.26,
      gapRampSeconds: 90.0,
    ),
    score: ScoreConfig(
      perWorldUnit: 0.1,
      nearMiss: 25.0,
      orb: 50.0,
      nearMissMargin: 1.5,
    ),
    pools: PoolConfig(
      maxObstacles: 96,
      maxOrbs: 16,
      maxParticles: 320,
      maxPickups: 8,
      maxPortals: 2,
    ),
    portal: PortalConfig.neonDash,
    bonus: BonusConfig(
      slotCount: 3,
      pickupRadius: 2.1,
      pickupChance: 0.26,
      magnetRadius: 26.0,
      magnetPullPerSecond: 70.0,
      immunitySeconds: 0.18,
    ),
    simulation: SimulationConfig(
      fixedStep: 1.0 / 120.0,
      maxStepsPerFrame: 4,
    ),
    wave: WaveConfig(
      boxHalfHeight: 2.0,
      pylonHalfHeight: 6.0,
      spikeHalfWidth: 1.9,
      spikeHalfHeight: 3.0,
      mineRadius: 1.9,
      minesPerWave: 3,
      combSlots: 4,
      driftUnlocksAtSeconds: 30.0,
      driftAmplitudeFraction: 0.055,
      driftRateHz: 0.22,
      gapMargin: 1.4,
      gateSwingFraction: 0.085,
      gateRateHz: 0.42,
      weaveSafetyFactor: 1.7,
      weaveMinSpacing: 20.0,
    ),
    route: RouteConfig.neonDash,
    orbRadius: 1.5,
    orbChance: 0.55,
    particleLifetime: 0.6,
    particleSpeed: 34.0,
    trailCapacity: 28,
    trailSampleInterval: 0.022,
  );
}
