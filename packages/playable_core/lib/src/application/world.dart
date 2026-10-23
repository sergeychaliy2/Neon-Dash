import 'dart:typed_data';

import '../config/game_config.dart';
import '../domain/bonus_kind.dart';
import '../domain/game_event.dart';
import '../domain/game_phase.dart';
import '../domain/obstacle_shape.dart';
import '../domain/portal_kind.dart';
import '../domain/route.dart';

abstract interface class WorldView {
  GameConfig get config;

  double get fieldWidth;

  double get fieldHeight;

  GamePhase get phase;

  double get elapsed;

  double get distance;

  Route get route;

  double get routeDistance;

  double get routeProgress;

  double get routeRemaining;

  int get checkpointsPassed;

  int get continuesUsed;

  int get bonusesSpent;

  bool holdsBonus(BonusKind kind);

  int get portalCount;
  Float32List get portalY;
  PortalKind portalKindAt(int index);

  PortalKind? get portal;

  double get portalRemaining;

  bool get controlsMirrored;

  HazardClass get hazard;

  double get scrollSpeed;

  double get score;
  int get nearMissCount;
  int get orbsCollected;

  double get playerX;

  double get playerY;
  double get playerRadius;

  double get playerTilt;

  int get obstacleCount;
  Float32List get obstacleX;
  Float32List get obstacleY;
  Float32List get obstacleHalfWidth;
  Float32List get obstacleHalfHeight;

  ObstacleShape obstacleShapeAt(int index);

  int get orbCount;
  Float32List get orbX;
  Float32List get orbY;

  int get pickupCount;
  Float32List get pickupX;
  Float32List get pickupY;
  BonusKind pickupKindAt(int index);

  int get slotCount;

  BonusKind? slotAt(int index);

  double remainingFor(BonusKind kind);

  bool isActive(BonusKind kind);

  int get shieldCharges;

  bool get isImmune;

  int get hitsTaken;

  double get worldSpeedScale;

  double get scoreScale;

  int get particleCount;
  Float32List get particleX;
  Float32List get particleY;

  Float32List get particleLife;
  Float32List get particleHue;

  int get trailCount;
  int get trailHead;
  int get trailCapacity;
  Float32List get trailX;
  Float32List get trailY;

  int get eventCount;
  GameEvent eventAt(int index);
}

class World implements WorldView {
  World(this.config)
      : obstacleX = Float32List(config.pools.maxObstacles),
        obstacleY = Float32List(config.pools.maxObstacles),
        obstacleHalfWidth = Float32List(config.pools.maxObstacles),
        obstacleHalfHeight = Float32List(config.pools.maxObstacles),
        obstacleShapeIndex = Uint8List(config.pools.maxObstacles),
        obstacleHomeX = Float32List(config.pools.maxObstacles),
        obstacleDriftAmplitude = Float32List(config.pools.maxObstacles),
        obstacleDriftRate = Float32List(config.pools.maxObstacles),
        obstacleDriftPhase = Float32List(config.pools.maxObstacles),
        obstacleNearestSquared = Float32List(config.pools.maxObstacles),
        obstacleScored = Uint8List(config.pools.maxObstacles),
        orbX = Float32List(config.pools.maxOrbs),
        orbY = Float32List(config.pools.maxOrbs),
        pickupX = Float32List(config.pools.maxPickups),
        pickupY = Float32List(config.pools.maxPickups),
        pickupKindIndex = Uint8List(config.pools.maxPickups),
        portalY = Float32List(config.pools.maxPortals),
        portalKindIndex = Uint8List(config.pools.maxPortals),
        slotKindIndex = Uint8List(config.bonus.slotCount)..fillRange(
            0,
            config.bonus.slotCount,
            emptySlot,
          ),
        bonusRemaining = Float32List(BonusKind.values.length),
        particleX = Float32List(config.pools.maxParticles),
        particleY = Float32List(config.pools.maxParticles),
        particleVelocityX = Float32List(config.pools.maxParticles),
        particleVelocityY = Float32List(config.pools.maxParticles),
        particleLife = Float32List(config.pools.maxParticles),
        particleHue = Float32List(config.pools.maxParticles),
        trailX = Float32List(config.trailCapacity),
        trailY = Float32List(config.trailCapacity),
        _eventCodes = Uint8List(eventCapacity),
        fieldWidth = config.viewport.worldHeight * config.viewport.minFieldAspect;

  static const int eventCapacity = 16;

  @override
  final GameConfig config;

  @override
  double fieldWidth;

  @override
  double get fieldHeight => config.viewport.worldHeight;

  @override
  GamePhase phase = GamePhase.ready;

  @override
  double elapsed = 0.0;

  @override
  double distance = 0.0;

  @override
  Route route = Route.forStage(1);

  @override
  double routeDistance = 0.0;

  int segmentIndex = 0;

  @override
  int checkpointsPassed = 0;

  @override
  int continuesUsed = 0;

  @override
  int bonusesSpent = 0;

  @override
  double get routeProgress => route.progressAt(routeDistance);

  @override
  double get routeRemaining => route.length - routeDistance;

  @override
  HazardClass get hazard => route.classOfSegment(segmentIndex);

  bool resumeAtCheckpoint() {
    if (checkpointsPassed <= 0) return false;

    routeDistance = route.checkpointDistance[checkpointsPassed - 1];
    segmentIndex = route.segmentAt(routeDistance);

    obstacleCount = 0;
    orbCount = 0;
    particleCount = 0;
    pickupCount = 0;
    portalCount = 0;
    endPortal();
    trailCount = 0;
    trailHead = 0;
    trailSampleCountdown = 0.0;

    playerX = fieldWidth * 0.5;
    playerTargetX = playerX;
    playerTilt = 0.0;

    immunityRemaining = config.bonus.immunitySeconds * 2.0;
    continuesUsed++;
    phase = GamePhase.running;
    return true;
  }

  void setStage(int stage) {
    route = Route.forStage(stage, config: config.route);
    routeDistance = 0.0;
    segmentIndex = 0;
    checkpointsPassed = 0;
  }

  @override
  double scrollSpeed = 0.0;

  @override
  double score = 0.0;

  @override
  int nearMissCount = 0;

  @override
  int orbsCollected = 0;

  @override
  double playerX = 0.0;

  double playerTargetX = 0.0;

  @override
  double playerTilt = 0.0;

  @override
  double get playerY => config.player.lineY;

  @override
  double get playerRadius => config.player.radius * (portal?.radiusScale ?? 1.0);

  @override
  int obstacleCount = 0;

  @override
  final Float32List obstacleX;

  @override
  final Float32List obstacleY;

  @override
  final Float32List obstacleHalfWidth;

  @override
  final Float32List obstacleHalfHeight;

  final Uint8List obstacleShapeIndex;

  @override
  ObstacleShape obstacleShapeAt(int index) =>
      ObstacleShape.values[obstacleShapeIndex[index]];

  final Float32List obstacleHomeX;
  final Float32List obstacleDriftAmplitude;
  final Float32List obstacleDriftRate;
  final Float32List obstacleDriftPhase;

  final Float32List obstacleNearestSquared;

  final Uint8List obstacleScored;

  @override
  int orbCount = 0;

  @override
  final Float32List orbX;

  @override
  final Float32List orbY;

  @override
  int particleCount = 0;

  @override
  final Float32List particleX;

  @override
  final Float32List particleY;

  final Float32List particleVelocityX;

  final Float32List particleVelocityY;

  @override
  final Float32List particleLife;

  @override
  final Float32List particleHue;

  @override
  int trailCount = 0;

  @override
  int trailHead = 0;

  @override
  int get trailCapacity => config.trailCapacity;

  @override
  final Float32List trailX;

  @override
  final Float32List trailY;

  double trailSampleCountdown = 0.0;

  int speedTier = 0;

  final Uint8List _eventCodes;

  @override
  int eventCount = 0;

  @override
  GameEvent eventAt(int index) => GameEvent.values[_eventCodes[index]];

  void pushEvent(GameEvent event) {
    if (eventCount >= eventCapacity) return;
    _eventCodes[eventCount++] = event.index;
  }

  void clearEvents() => eventCount = 0;

  void resetRun() {
    phase = GamePhase.ready;
    elapsed = 0.0;
    distance = 0.0;
    routeDistance = 0.0;
    segmentIndex = 0;
    checkpointsPassed = 0;
    continuesUsed = 0;
    bonusesSpent = 0;
    scrollSpeed = config.difficulty.startScrollSpeed;
    score = 0.0;
    nearMissCount = 0;
    orbsCollected = 0;
    speedTier = 0;

    playerX = fieldWidth * 0.5;
    playerTargetX = playerX;
    playerTilt = 0.0;

    obstacleCount = 0;
    orbCount = 0;
    particleCount = 0;
    pickupCount = 0;
    portalCount = 0;
    endPortal();

    slotKindIndex.fillRange(0, slotKindIndex.length, emptySlot);
    bonusRemaining.fillRange(0, bonusRemaining.length, 0.0);
    shieldCharges = config.bonus.startingShields;
    hitsTaken = 0;
    immunityRemaining = 0.0;

    trailCount = 0;
    trailHead = 0;
    trailSampleCountdown = 0.0;

    eventCount = 0;
  }

  void setFieldWidth(double width) {
    if (width <= 0.0 || width == fieldWidth) return;

    final ratio = fieldWidth > 0.0 ? width / fieldWidth : 1.0;
    fieldWidth = width;

    playerX *= ratio;
    playerTargetX *= ratio;

    for (var i = 0; i < obstacleCount; i++) {
      obstacleX[i] *= ratio;
      obstacleHomeX[i] *= ratio;
      obstacleHalfWidth[i] *= ratio;
      obstacleDriftAmplitude[i] *= ratio;
      obstacleNearestSquared[i] = double.infinity;
    }
    for (var i = 0; i < orbCount; i++) {
      orbX[i] *= ratio;
    }
    for (var i = 0; i < pickupCount; i++) {
      pickupX[i] *= ratio;
    }
    for (var i = 0; i < particleCount; i++) {
      particleX[i] *= ratio;
    }
    for (var i = 0; i < trailCount; i++) {
      trailX[i] *= ratio;
    }

    final radius = config.player.radius;
    final rightLimit = fieldWidth - radius;
    if (playerX > rightLimit) playerX = rightLimit;
    if (playerX < radius) playerX = radius;
    if (playerTargetX > rightLimit) playerTargetX = rightLimit;
    if (playerTargetX < radius) playerTargetX = radius;
  }

  bool addObstacle({
    required double x,
    required double y,
    required double halfWidth,
    required double halfHeight,
    required ObstacleShape shape,
    double driftAmplitude = 0.0,
    double driftRate = 0.0,
    double driftPhase = 0.0,
  }) {
    if (obstacleCount >= config.pools.maxObstacles) return false;
    final i = obstacleCount++;
    obstacleX[i] = x;
    obstacleY[i] = y;
    obstacleHalfWidth[i] = halfWidth;
    obstacleHalfHeight[i] = halfHeight;
    obstacleShapeIndex[i] = shape.index;
    obstacleHomeX[i] = x;
    obstacleDriftAmplitude[i] = driftAmplitude;
    obstacleDriftRate[i] = driftRate;
    obstacleDriftPhase[i] = driftPhase;
    obstacleNearestSquared[i] = double.infinity;
    obstacleScored[i] = 0;
    return true;
  }

  void removeObstacleAt(int index) {
    final last = --obstacleCount;
    if (index == last) return;
    obstacleX[index] = obstacleX[last];
    obstacleY[index] = obstacleY[last];
    obstacleHalfWidth[index] = obstacleHalfWidth[last];
    obstacleHalfHeight[index] = obstacleHalfHeight[last];
    obstacleShapeIndex[index] = obstacleShapeIndex[last];
    obstacleHomeX[index] = obstacleHomeX[last];
    obstacleDriftAmplitude[index] = obstacleDriftAmplitude[last];
    obstacleDriftRate[index] = obstacleDriftRate[last];
    obstacleDriftPhase[index] = obstacleDriftPhase[last];
    obstacleNearestSquared[index] = obstacleNearestSquared[last];
    obstacleScored[index] = obstacleScored[last];
  }

  bool addOrb({required double x, required double y}) {
    if (orbCount >= config.pools.maxOrbs) return false;
    final i = orbCount++;
    orbX[i] = x;
    orbY[i] = y;
    return true;
  }

  void removeOrbAt(int index) {
    final last = --orbCount;
    if (index == last) return;
    orbX[index] = orbX[last];
    orbY[index] = orbY[last];
  }

  static const int emptySlot = 0xFF;

  @override
  @override
  int portalCount = 0;

  @override
  final Float32List portalY;

  final Uint8List portalKindIndex;

  @override
  PortalKind portalKindAt(int index) =>
      PortalKind.values[portalKindIndex[index]];

  int activePortalIndex = -1;

  @override
  double portalRemaining = 0.0;

  @override
  PortalKind? get portal =>
      activePortalIndex < 0 ? null : PortalKind.values[activePortalIndex];

  @override
  bool get controlsMirrored => portal?.mirrors ?? false;

  bool addPortal({required double y, required PortalKind kind}) {
    if (portalCount >= config.pools.maxPortals) return false;
    final i = portalCount++;
    portalY[i] = y;
    portalKindIndex[i] = kind.index;
    return true;
  }

  void removePortalAt(int index) {
    final last = --portalCount;
    portalY[index] = portalY[last];
    portalKindIndex[index] = portalKindIndex[last];
  }

  void beginPortal(PortalKind kind) {
    activePortalIndex = kind.index;
    portalRemaining = kind.seconds;
  }

  void endPortal() {
    activePortalIndex = -1;
    portalRemaining = 0.0;
  }

  @override
  int pickupCount = 0;

  @override
  final Float32List pickupX;

  @override
  final Float32List pickupY;

  final Uint8List pickupKindIndex;

  @override
  BonusKind pickupKindAt(int index) =>
      BonusKind.values[pickupKindIndex[index]];

  final Uint8List slotKindIndex;

  @override
  int get slotCount => slotKindIndex.length;

  @override
  BonusKind? slotAt(int index) {
    final value = slotKindIndex[index];
    return value == emptySlot ? null : BonusKind.values[value];
  }

  final Float32List bonusRemaining;

  @override
  double remainingFor(BonusKind kind) => bonusRemaining[kind.index];

  @override
  bool isActive(BonusKind kind) => kind.isCharge
      ? shieldCharges > 0
      : bonusRemaining[kind.index] > 0.0;

  @override
  int shieldCharges = 0;

  @override
  int hitsTaken = 0;

  double immunityRemaining = 0.0;

  @override
  bool get isImmune => immunityRemaining > 0.0;

  @override
  double get worldSpeedScale {
    var scale = 1.0;
    for (var i = 0; i < BonusKind.values.length; i++) {
      if (bonusRemaining[i] <= 0.0) continue;
      scale *= BonusKind.values[i].worldSpeedScale;
    }
    return scale;
  }

  @override
  double get scoreScale {
    var scale = 1.0;
    for (var i = 0; i < BonusKind.values.length; i++) {
      if (bonusRemaining[i] <= 0.0) continue;
      scale *= BonusKind.values[i].scoreScale;
    }
    return scale;
  }

  bool addPickup({
    required double x,
    required double y,
    required BonusKind kind,
  }) {
    if (pickupCount >= config.pools.maxPickups) return false;
    final i = pickupCount++;
    pickupX[i] = x;
    pickupY[i] = y;
    pickupKindIndex[i] = kind.index;
    return true;
  }

  void removePickupAt(int index) {
    final last = --pickupCount;
    if (index == last) return;
    pickupX[index] = pickupX[last];
    pickupY[index] = pickupY[last];
    pickupKindIndex[index] = pickupKindIndex[last];
  }

  @override
  bool holdsBonus(BonusKind kind) {
    for (var i = 0; i < slotKindIndex.length; i++) {
      if (slotKindIndex[i] == kind.index) return true;
    }
    return false;
  }

  bool storeBonus(BonusKind kind) {
    if (holdsBonus(kind)) return false;

    for (var i = 0; i < slotKindIndex.length; i++) {
      if (slotKindIndex[i] != emptySlot) continue;
      slotKindIndex[i] = kind.index;
      return true;
    }
    return false;
  }

  BonusKind? takeFromSlot(int index) {
    if (index < 0 || index >= slotKindIndex.length) return null;
    final value = slotKindIndex[index];
    if (value == emptySlot) return null;
    slotKindIndex[index] = emptySlot;
    return BonusKind.values[value];
  }

  void beginBonus(BonusKind kind) {
    if (kind.graceSeconds > immunityRemaining) {
      immunityRemaining = kind.graceSeconds;
    }

    if (kind.isCharge) {
      shieldCharges++;
      return;
    }
    final full = kind.seconds * config.bonus.durationScale;
    if (bonusRemaining[kind.index] < full) bonusRemaining[kind.index] = full;
  }

  bool addParticle({
    required double x,
    required double y,
    required double velocityX,
    required double velocityY,
    required double life,
    required double hue,
  }) {
    if (particleCount >= config.pools.maxParticles) return false;
    final i = particleCount++;
    particleX[i] = x;
    particleY[i] = y;
    particleVelocityX[i] = velocityX;
    particleVelocityY[i] = velocityY;
    particleLife[i] = life;
    particleHue[i] = hue;
    return true;
  }

  void removeParticleAt(int index) {
    final last = --particleCount;
    if (index == last) return;
    particleX[index] = particleX[last];
    particleY[index] = particleY[last];
    particleVelocityX[index] = particleVelocityX[last];
    particleVelocityY[index] = particleVelocityY[last];
    particleLife[index] = particleLife[last];
    particleHue[index] = particleHue[last];
  }

  void pushTrailSample(double x, double y) {
    trailHead = trailCount == 0 ? 0 : (trailHead + 1) % trailCapacity;
    trailX[trailHead] = x;
    trailY[trailHead] = y;
    if (trailCount < trailCapacity) trailCount++;
  }
}
