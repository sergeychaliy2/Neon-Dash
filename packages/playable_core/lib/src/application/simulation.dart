import 'dart:math' as math;

import '../config/game_config.dart';
import '../domain/bonus_kind.dart';
import '../domain/collision.dart';
import 'package:playable_kit/playable_kit.dart';
import '../domain/game_event.dart';
import '../domain/game_phase.dart';
import '../domain/obstacle_shape.dart';
import 'difficulty_curve.dart';
import 'spawner.dart';
import 'world.dart';

class Simulation {
  Simulation({
    required GameConfig config,
    required DeterministicRandom random,
    DeterministicRandom? layout,
  })  : _config = config,
        _random = random,
        _curve = DifficultyCurve(config.difficulty),
        _spawner = Spawner(config: config, random: layout ?? random),
        _playerFollowFactor = _approachFactor(
          config.player.followRate,
          config.simulation.fixedStep,
        ),
        _tiltFollowFactor = _approachFactor(
          _tiltFollowRate,
          config.simulation.fixedStep,
        ),
        _particleDamping = math.exp(
          -_particleDragRate * config.simulation.fixedStep,
        );

  static const double _tiltFollowRate = 9.0;

  static const double _particleDragRate = 3.1;

  static const double _speedTierWidth = 12.0;

  static const int _nearMissBurstParticles = 9;
  static const int _orbBurstParticles = 16;
  static const int _crashBurstParticles = 96;
  static const int _bonusBurstParticles = 18;
  static const int _shieldBurstParticles = 40;

  static const double _orbHue = 52.0;
  static const double _crashHue = 8.0;
  static const double _hueJitter = 14.0;
  static const double _tau = 6.283185307179586;

  final GameConfig _config;
  final DeterministicRandom _random;
  final DifficultyCurve _curve;
  final Spawner _spawner;

  final double _playerFollowFactor;
  final double _tiltFollowFactor;
  final double _particleDamping;

  static double _approachFactor(double rate, double dt) =>
      1.0 - math.exp(-rate * dt);

  void reset() => _spawner.reset();

  void step(World world) {
    final dt = _config.simulation.fixedStep;

    switch (world.phase) {
      case GamePhase.ready:
        world.scrollSpeed = _config.difficulty.startScrollSpeed;
        world.distance += world.scrollSpeed * dt;
        _updatePlayer(world, dt);
        _updateTrail(world, dt);
        _updateParticles(world, dt);

      case GamePhase.running:
        world.elapsed += dt;
        _updateBonusTimers(world, dt);
        _updatePortal(world, dt);

        final baseSpeed = _curve.scrollSpeedAt(world.elapsed);
        _recordSpeedTier(world, baseSpeed);
        world.scrollSpeed =
            baseSpeed * world.worldSpeedScale * _portalScroll(world);

        final travelled = world.scrollSpeed * dt;
        world.distance += travelled;
        world.routeDistance += travelled;
        world.score += travelled *
            _config.score.perWorldUnit *
            world.scoreScale *
            (world.portal?.scoreScale ?? 1.0);

        _updatePlayer(world, dt);
        _updateTrail(world, dt);
        _spawner.update(world, dt);
        _moveObstacles(world, dt);
        _updateOrbs(world, dt);
        _updatePickups(world, dt);
        _movePortals(world, dt);
        _updateParticles(world, dt);
        _resolveCollisions(world);
        if (world.phase == GamePhase.running) _advanceRoute(world);

      case GamePhase.over || GamePhase.finished:
        world.distance += world.scrollSpeed * dt;
        _updateTrail(world, dt);
        _moveObstacles(world, dt);
        _updateParticles(world, dt);
    }
  }

  void _advanceRoute(World world) {
    final route = world.route;

    while (world.segmentIndex + 1 < route.segmentCount &&
        world.routeDistance >= route.segmentStart[world.segmentIndex + 1]) {
      world.segmentIndex++;
    }

    while (world.checkpointsPassed < route.checkpointCount &&
        world.routeDistance >=
            route.checkpointDistance[world.checkpointsPassed]) {
      world.checkpointsPassed++;
      world.pushEvent(GameEvent.checkpointPassed);
    }

    if (world.routeDistance < route.length) return;

    world.phase = GamePhase.finished;
    world.pushEvent(GameEvent.stageCleared);
  }

  void _recordSpeedTier(World world, double baseSpeed) {
    final above = baseSpeed - _config.difficulty.startScrollSpeed;
    final tier = (above / _speedTierWidth).floor();
    if (tier <= world.speedTier) return;
    world.speedTier = tier;
    world.pushEvent(GameEvent.speedTierUp);
  }

  void _updatePlayer(World world, double dt) {
    final maxDelta = _config.player.speedInWidths * world.fieldWidth * dt;

    var delta = (world.playerTargetX - world.playerX) * _playerFollowFactor;
    if (delta > maxDelta) {
      delta = maxDelta;
    } else if (delta < -maxDelta) {
      delta = -maxDelta;
    }

    var x = world.playerX + delta;
    final radius = world.playerRadius;
    final rightLimit = world.fieldWidth - radius;
    if (x < radius) {
      x = radius;
    } else if (x > rightLimit) {
      x = rightLimit;
    }
    world.playerX = x;

    final tiltTarget = maxDelta > 0.0 ? delta / maxDelta : 0.0;
    world.playerTilt += (tiltTarget - world.playerTilt) * _tiltFollowFactor;
  }

  void _updateTrail(World world, double dt) {
    final shift = world.scrollSpeed * dt;
    final trailY = world.trailY;
    for (var i = 0; i < world.trailCount; i++) {
      trailY[i] += shift;
    }

    world.trailSampleCountdown -= dt;
    if (world.trailSampleCountdown > 0.0) return;

    world.trailSampleCountdown += _config.trailSampleInterval;
    if (world.trailSampleCountdown <= 0.0) {
      world.trailSampleCountdown = _config.trailSampleInterval;
    }
    world.pushTrailSample(world.playerX, world.playerY);
  }

  void _moveObstacles(World world, double dt) {
    final shift = world.scrollSpeed * dt;
    final limit = world.fieldHeight;
    for (var i = world.obstacleCount - 1; i >= 0; i--) {
      final y = world.obstacleY[i] + shift;
      if (y - world.obstacleHalfHeight[i] > limit) {
        world.removeObstacleAt(i);
        continue;
      }
      world.obstacleY[i] = y;

      final amplitude = world.obstacleDriftAmplitude[i];
      if (amplitude <= 0.0) continue;

      var phase = world.obstacleDriftPhase[i] +
          world.obstacleDriftRate[i] * dt;
      if (phase >= 1.0) phase -= 1.0;
      world.obstacleDriftPhase[i] = phase;
      world.obstacleX[i] =
          world.obstacleHomeX[i] + amplitude * math.sin(phase * _tau);
    }
  }

  double _squaredDistanceToObstacle(
    World world,
    int index,
    double pointX,
    double pointY,
  ) {
    final x = world.obstacleX[index];
    final y = world.obstacleY[index];
    final halfWidth = world.obstacleHalfWidth[index];
    final halfHeight = world.obstacleHalfHeight[index];

    switch (world.obstacleShapeAt(index)) {
      case ObstacleShape.box:
        return squaredDistanceToBox(
          pointX,
          pointY,
          x,
          y,
          halfWidth,
          halfHeight,
        );

      case ObstacleShape.spike:
        return squaredDistanceToTriangle(
          pointX,
          pointY,
          x - halfWidth,
          y - halfHeight,
          x + halfWidth,
          y - halfHeight,
          x,
          y + halfHeight,
        );

      case ObstacleShape.wedge:
        final leansLeft = x < world.fieldWidth * 0.5;
        return squaredDistanceToTriangle(
          pointX,
          pointY,
          x - halfWidth,
          y - halfHeight,
          x + halfWidth,
          y - halfHeight,
          leansLeft ? x - halfWidth : x + halfWidth,
          y + halfHeight,
        );

      case ObstacleShape.mine:
      case ObstacleShape.saw:
        final dx = pointX - x;
        final dy = pointY - y;
        final toRim = math.sqrt(dx * dx + dy * dy) - halfWidth;
        return toRim <= 0.0 ? 0.0 : toRim * toRim;
    }
  }

  void _updateOrbs(World world, double dt) {
    final shift = world.scrollSpeed * dt;
    final limit = world.fieldHeight;
    final playerX = world.playerX;
    final playerY = world.playerY;
    final reach = world.playerRadius + _config.orbRadius;
    final reachSquared = reach * reach;

    final magnetActive = world.isActive(BonusKind.magnet);
    final magnetRange =
        _config.bonus.magnetRadius * _config.bonus.magnetRadius;
    final pull = _config.bonus.magnetPullPerSecond * dt;

    for (var i = world.orbCount - 1; i >= 0; i--) {
      var x = world.orbX[i];
      var y = world.orbY[i] + shift;

      if (magnetActive) {
        final towardX = playerX - x;
        final towardY = playerY - y;
        final rangeSquared = towardX * towardX + towardY * towardY;
        if (rangeSquared > 0.0 && rangeSquared < magnetRange) {
          final range = math.sqrt(rangeSquared);
          x += towardX / range * pull;
          y += towardY / range * pull;
          world.orbX[i] = x;
        }
      }

      final dx = x - playerX;
      final dy = y - playerY;
      if (dx * dx + dy * dy <= reachSquared) {
        world.orbsCollected++;
        world.score += _config.score.orb;
        world.pushEvent(GameEvent.orbCollected);
        _emitBurst(world, x, y, _orbHue, _orbBurstParticles);
        world.removeOrbAt(i);
        continue;
      }

      if (y - _config.orbRadius > limit) {
        world.removeOrbAt(i);
        continue;
      }
      world.orbY[i] = y;
    }
  }

  void _updateParticles(World world, double dt) {
    final shift = world.scrollSpeed * dt;
    for (var i = world.particleCount - 1; i >= 0; i--) {
      final life = world.particleLife[i] - dt;
      if (life <= 0.0) {
        world.removeParticleAt(i);
        continue;
      }
      world.particleLife[i] = life;

      final velocityX = world.particleVelocityX[i] * _particleDamping;
      final velocityY = world.particleVelocityY[i] * _particleDamping;
      world.particleVelocityX[i] = velocityX;
      world.particleVelocityY[i] = velocityY;
      world.particleX[i] += velocityX * dt;
      world.particleY[i] += velocityY * dt + shift;
    }
  }

  void _resolveCollisions(World world) {
    final playerX = world.playerX;
    final playerY = world.playerY;
    final radius = world.playerRadius;
    final crashLimitSquared = radius * radius;
    final nearReach = radius + _config.score.nearMissMargin;
    final nearLimitSquared = nearReach * nearReach;

    for (var i = 0; i < world.obstacleCount; i++) {
      final distanceSquared =
          _squaredDistanceToObstacle(world, i, playerX, playerY);

      if (distanceSquared < world.obstacleNearestSquared[i]) {
        world.obstacleNearestSquared[i] = distanceSquared;
      }

      if (distanceSquared <= crashLimitSquared) {
        _takeHit(world);
        if (world.phase != GamePhase.running) return;
        continue;
      }

      final hasPassed =
          world.obstacleY[i] - world.obstacleHalfHeight[i] > playerY;
      if (world.obstacleScored[i] != 0 || !hasPassed) continue;

      world.obstacleScored[i] = 1;
      if (world.obstacleNearestSquared[i] > nearLimitSquared) continue;

      world.nearMissCount++;
      world.score += _config.score.nearMiss;
      world.pushEvent(GameEvent.nearMiss);
      _emitBurst(
        world,
        playerX,
        playerY,
        world.obstacleShapeAt(i).hue,
        _nearMissBurstParticles,
      );
    }
  }

  double _portalScroll(World world) => world.portal?.scrollScale ?? 1.0;

  void _updatePortal(World world, double dt) {
    if (world.portalRemaining <= 0.0) return;

    final left = world.portalRemaining - dt;
    if (left > 0.0) {
      world.portalRemaining = left;
      return;
    }
    world
      ..endPortal()
      ..pushEvent(GameEvent.portalEnded);
  }

  void _movePortals(World world, double dt) {
    final shift = world.scrollSpeed * dt;
    final line = world.playerY;

    for (var i = world.portalCount - 1; i >= 0; i--) {
      final was = world.portalY[i];
      final now = was + shift;

      if (was <= line && now >= line) {
        world
          ..beginPortal(world.portalKindAt(i))
          ..pushEvent(GameEvent.portalEntered);
        world.removePortalAt(i);
        continue;
      }

      if (now > world.fieldHeight) {
        world.removePortalAt(i);
        continue;
      }
      world.portalY[i] = now;
    }
  }

  void _updateBonusTimers(World world, double dt) {
    for (var i = 0; i < BonusKind.values.length; i++) {
      final remaining = world.bonusRemaining[i];
      if (remaining <= 0.0) continue;
      final next = remaining - dt;
      world.bonusRemaining[i] = next > 0.0 ? next : 0.0;
    }

    if (world.immunityRemaining <= 0.0) return;
    final grace = world.immunityRemaining - dt;
    world.immunityRemaining = grace > 0.0 ? grace : 0.0;
  }

  void _updatePickups(World world, double dt) {
    final shift = world.scrollSpeed * dt;
    final limit = world.fieldHeight;
    final radius = _config.bonus.pickupRadius;
    final reach = world.playerRadius + radius;
    final reachSquared = reach * reach;

    for (var i = world.pickupCount - 1; i >= 0; i--) {
      final x = world.pickupX[i];
      final y = world.pickupY[i] + shift;

      final dx = x - world.playerX;
      final dy = y - world.playerY;
      if (dx * dx + dy * dy <= reachSquared) {
        final kind = world.pickupKindAt(i);
        if (world.storeBonus(kind)) {
          world.pushEvent(GameEvent.bonusCollected);
          _emitBurst(world, x, y, kind.hue, _bonusBurstParticles);
          world.removePickupAt(i);
          continue;
        }
      }

      if (y - radius > limit) {
        world.removePickupAt(i);
        continue;
      }
      world.pickupY[i] = y;
    }
  }

  void _takeHit(World world) {
    if (world.isImmune) return;

    world.hitsTaken++;

    if (world.shieldCharges > 0) {
      world.shieldCharges--;
      world.immunityRemaining = _config.bonus.immunitySeconds;
      world.pushEvent(GameEvent.shieldAbsorbed);
      _emitBurst(
        world,
        world.playerX,
        world.playerY,
        BonusKind.shield.hue,
        _shieldBurstParticles,
      );
      return;
    }

    _crash(world);
  }

  void _crash(World world) {
    world.phase = GamePhase.over;
    world.playerTilt = 0.0;
    world.pushEvent(GameEvent.crashed);
    _emitBurst(
      world,
      world.playerX,
      world.playerY,
      _crashHue,
      _crashBurstParticles,
    );
  }

  void _emitBurst(
    World world,
    double x,
    double y,
    double hue,
    int count,
  ) {
    final lifetime = _config.particleLifetime;
    final speed = _config.particleSpeed;

    for (var i = 0; i < count; i++) {
      final angle = _random.nextDouble() * _tau;
      final magnitude = _random.nextRange(speed * 0.3, speed);
      final spawned = world.addParticle(
        x: x,
        y: y,
        velocityX: math.cos(angle) * magnitude,
        velocityY: math.sin(angle) * magnitude,
        life: _random.nextRange(lifetime * 0.45, lifetime),
        hue: hue + _random.nextRange(-_hueJitter, _hueJitter),
      );
      if (!spawned) return;
    }
  }
}
